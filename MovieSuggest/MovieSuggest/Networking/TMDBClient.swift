import Foundation
import SwiftUI
import os

enum TMDBError: LocalizedError {
    case missingAPIKey
    case invalidAPIKey
    case rateLimited
    case server(statusCode: Int)
    case network(underlying: Error)
    case decoding(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No TMDB API key is set. Add one in Settings."
        case .invalidAPIKey:
            return "TMDB rejected the API key. Check it in Settings."
        case .rateLimited:
            return "TMDB rate limit reached. Try again in a moment."
        case .server(let statusCode):
            return "TMDB returned an error (HTTP \(statusCode))."
        case .network:
            return "Network error. Check your connection and try again."
        case .decoding:
            return "Unexpected response from TMDB."
        }
    }

    /// True when the failure is an in-flight request cancelled by a newer one
    /// (e.g. search-as-you-type) — not worth surfacing to the user.
    var isCancellation: Bool {
        if case .network(let underlying) = self {
            return (underlying as? URLError)?.code == .cancelled
        }
        return false
    }
}

/// Thin async wrapper around the TMDB v3 REST API. The API key is read
/// lazily per-request so key changes in Settings take effect immediately.
actor TMDBClient {
    private let session: URLSession
    private let apiKeyProvider: @Sendable () -> String?
    private let decoder = TMDBClient.makeDecoder()

    init(session: URLSession = .shared, apiKeyProvider: @escaping @Sendable () -> String?) {
        self.session = session
        self.apiKeyProvider = apiKeyProvider
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    // MARK: - Endpoints

    func searchMovies(query: String, page: Int = 1) async throws -> TMDBPagedResponse<TMDBMovie> {
        try await request("/search/movie", query: [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "include_adult", value: "false"),
        ])
    }

    func trending() async throws -> TMDBPagedResponse<TMDBMovie> {
        try await request("/trending/movie/week")
    }

    func discover(genreIDs: [Int], originalLanguage: String?, page: Int = 1, keywordIDs: [Int] = []) async throws -> TMDBPagedResponse<TMDBMovie> {
        // 200 sounds like a low bar but is actually steep for most non-
        // Hollywood cinema — many well-regarded regional-language films
        // simply never accumulate that many TMDB user ratings. 30 still
        // filters out ratingless/junk entries without starving smaller
        // catalogs of real results.
        var items: [URLQueryItem] = [
            URLQueryItem(name: "sort_by", value: "popularity.desc"),
            URLQueryItem(name: "vote_count.gte", value: "30"),
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "page", value: String(page)),
        ]
        if !genreIDs.isEmpty {
            // "|" means OR; "," would require a movie to match every genre.
            items.append(URLQueryItem(name: "with_genres", value: genreIDs.map(String.init).joined(separator: "|")))
        }
        if let originalLanguage {
            items.append(URLQueryItem(name: "with_original_language", value: originalLanguage))
        }
        if !keywordIDs.isEmpty {
            items.append(URLQueryItem(name: "with_keywords", value: keywordIDs.map(String.init).joined(separator: "|")))
        }
        return try await request("/discover/movie", query: items)
    }

    /// Fans out `discover` across every language and page combination
    /// (concurrently), deduplicated by id. A single `discover` call only
    /// returns TMDB's first ~20 results for that language, so pulling
    /// several pages is what keeps the candidate pool large enough to
    /// survive quality and library-exclusion filtering downstream instead
    /// of collapsing to a handful of results.
    func discoverPages(genreIDs: [Int], languages: [String?], pageCount: Int, keywordIDs: [Int] = []) async -> [TMDBMovie] {
        var moviesByID: [Int: TMDBMovie] = [:]
        await withTaskGroup(of: [TMDBMovie].self) { group in
            for language in languages {
                for page in 1...max(1, pageCount) {
                    group.addTask { [self] in
                        (try? await self.discover(genreIDs: genreIDs, originalLanguage: language, page: page, keywordIDs: keywordIDs))?.results ?? []
                    }
                }
            }
            for await movies in group {
                for movie in movies where moviesByID[movie.id] == nil {
                    moviesByID[movie.id] = movie
                }
            }
        }
        return Array(moviesByID.values)
    }

    /// Text search over TMDB's keyword taxonomy — used to resolve a
    /// human-readable mood word (e.g. "feel-good") to the numeric keyword
    /// id `with_keywords` needs, since those ids aren't documented/stable.
    func searchKeyword(query: String) async throws -> [TMDBKeyword] {
        let response: TMDBKeywordSearchResponse = try await request("/search/keyword", query: [
            URLQueryItem(name: "query", value: query),
        ])
        return response.results
    }

    func movieDetails(id: Int) async throws -> TMDBMovieDetails {
        try await request("/movie/\(id)")
    }

    func recommendations(for id: Int) async throws -> TMDBPagedResponse<TMDBMovie> {
        try await request("/movie/\(id)/recommendations")
    }

    func similar(to id: Int) async throws -> TMDBPagedResponse<TMDBMovie> {
        try await request("/movie/\(id)/similar")
    }

    func genres() async throws -> [TMDBGenre] {
        let response: TMDBGenreListResponse = try await request("/genre/movie/list")
        return response.genres
    }

    /// Validates a candidate key (before it is saved) with a cheap request.
    func validate(apiKey: String) async throws {
        let _: TMDBGenreListResponse = try await request("/genre/movie/list", apiKeyOverride: apiKey)
    }

    func credits(for movieID: Int) async throws -> TMDBCredits {
        try await request("/movie/\(movieID)/credits")
    }

    /// A person's filmography (as both cast and crew member).
    func personMovieCredits(personID: Int) async throws -> TMDBPersonMovieCredits {
        try await request("/person/\(personID)/movie_credits")
    }

    /// Streaming/rent/buy availability, keyed by ISO 3166-1 region code
    /// (e.g. "US", "IN"). Backed by JustWatch data via TMDB.
    func watchProviders(for movieID: Int) async throws -> TMDBWatchProvidersResponse {
        try await request("/movie/\(movieID)/watch/providers")
    }

    func videos(for movieID: Int) async throws -> TMDBVideosResponse {
        try await request("/movie/\(movieID)/videos")
    }

    /// Recently released movies in a given language, newest first. Unlike
    /// `discover`, this has no meaningful vote-count floor — a movie that
    /// released last week hasn't had time to accumulate many ratings yet,
    /// so requiring a vote count here would filter out exactly the "new"
    /// releases this exists to surface.
    func newReleases(originalLanguage: String?, page: Int = 1) async throws -> TMDBPagedResponse<TMDBMovie> {
        let today = Date()
        let windowStart = Calendar(identifier: .gregorian).date(byAdding: .day, value: -90, to: today) ?? today
        var items: [URLQueryItem] = [
            URLQueryItem(name: "sort_by", value: "primary_release_date.desc"),
            URLQueryItem(name: "primary_release_date.lte", value: Self.dateOnlyFormatter.string(from: today)),
            URLQueryItem(name: "primary_release_date.gte", value: Self.dateOnlyFormatter.string(from: windowStart)),
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "page", value: String(page)),
        ]
        if let originalLanguage {
            items.append(URLQueryItem(name: "with_original_language", value: originalLanguage))
        }
        return try await request("/discover/movie", query: items)
    }

    /// Fans out `newReleases` across every language (concurrently),
    /// deduplicated by id, mirroring `discoverPages`.
    func newReleasesPages(languages: [String?], pageCount: Int) async -> [TMDBMovie] {
        var moviesByID: [Int: TMDBMovie] = [:]
        await withTaskGroup(of: [TMDBMovie].self) { group in
            for language in languages {
                for page in 1...max(1, pageCount) {
                    group.addTask { [self] in
                        (try? await self.newReleases(originalLanguage: language, page: page))?.results ?? []
                    }
                }
            }
            for await movies in group {
                for movie in movies where moviesByID[movie.id] == nil {
                    moviesByID[movie.id] = movie
                }
            }
        }
        return Array(moviesByID.values)
    }

    /// Movies releasing soon in a given language, soonest first. Like
    /// `newReleases`, no vote-count floor — unreleased movies have no votes
    /// at all yet.
    func comingSoon(originalLanguage: String?, page: Int = 1) async throws -> TMDBPagedResponse<TMDBMovie> {
        let today = Date()
        let windowEnd = Calendar(identifier: .gregorian).date(byAdding: .day, value: 60, to: today) ?? today
        var items: [URLQueryItem] = [
            URLQueryItem(name: "sort_by", value: "primary_release_date.asc"),
            URLQueryItem(name: "primary_release_date.gte", value: Self.dateOnlyFormatter.string(from: today)),
            URLQueryItem(name: "primary_release_date.lte", value: Self.dateOnlyFormatter.string(from: windowEnd)),
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "page", value: String(page)),
        ]
        if let originalLanguage {
            items.append(URLQueryItem(name: "with_original_language", value: originalLanguage))
        }
        return try await request("/discover/movie", query: items)
    }

    /// Fans out `comingSoon` across every language (concurrently),
    /// deduplicated by id, mirroring `newReleasesPages`.
    func comingSoonPages(languages: [String?], pageCount: Int) async -> [TMDBMovie] {
        var moviesByID: [Int: TMDBMovie] = [:]
        await withTaskGroup(of: [TMDBMovie].self) { group in
            for language in languages {
                for page in 1...max(1, pageCount) {
                    group.addTask { [self] in
                        (try? await self.comingSoon(originalLanguage: language, page: page))?.results ?? []
                    }
                }
            }
            for await movies in group {
                for movie in movies where moviesByID[movie.id] == nil {
                    moviesByID[movie.id] = movie
                }
            }
        }
        return Array(moviesByID.values)
    }

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    // MARK: - Core request

    private func request<T: Decodable>(
        _ path: String,
        query: [URLQueryItem] = [],
        apiKeyOverride: String? = nil
    ) async throws -> T {
        let key = apiKeyOverride ?? apiKeyProvider()
        guard let key, !key.isEmpty else {
            Log.network.error("\(path, privacy: .public): no API key set")
            throw TMDBError.missingAPIKey
        }

        var components = URLComponents(string: "https://api.themoviedb.org/3" + path)!
        components.queryItems = [URLQueryItem(name: "api_key", value: key)] + query

        let started = Date()
        Log.network.debug("→ \(path, privacy: .public) \(query.count, privacy: .public) query param(s)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: components.url!)
        } catch {
            Log.network.error("✗ \(path, privacy: .public) network error: \(error.localizedDescription, privacy: .public)")
            throw TMDBError.network(underlying: error)
        }

        let elapsedMs = Int(Date().timeIntervalSince(started) * 1000)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        switch statusCode {
        case 200...299:
            do {
                let decoded = try decoder.decode(T.self, from: data)
                Log.network.debug("← \(path, privacy: .public) \(statusCode, privacy: .public) in \(elapsedMs, privacy: .public)ms (\(data.count, privacy: .public) bytes)")
                return decoded
            } catch {
                Log.network.error("✗ \(path, privacy: .public) decode failed: \(error.localizedDescription, privacy: .public)")
                throw TMDBError.decoding(underlying: error)
            }
        case 401:
            Log.network.error("✗ \(path, privacy: .public) 401 invalid API key")
            throw TMDBError.invalidAPIKey
        case 429:
            Log.network.notice("✗ \(path, privacy: .public) 429 rate limited")
            throw TMDBError.rateLimited
        case let statusCode:
            Log.network.error("✗ \(path, privacy: .public) unexpected status \(statusCode, privacy: .public)")
            throw TMDBError.server(statusCode: statusCode)
        }
    }
}

// MARK: - SwiftUI environment

private struct TMDBClientKey: EnvironmentKey {
    static let defaultValue = TMDBClient(apiKeyProvider: { APIKeyStore.currentKey() })
}

extension EnvironmentValues {
    var tmdbClient: TMDBClient {
        get { self[TMDBClientKey.self] }
        set { self[TMDBClientKey.self] = newValue }
    }
}

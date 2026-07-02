import Foundation
import SwiftUI

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

    func discover(genreIDs: [Int], originalLanguage: String?, page: Int = 1) async throws -> TMDBPagedResponse<TMDBMovie> {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "sort_by", value: "popularity.desc"),
            URLQueryItem(name: "vote_count.gte", value: "200"),
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
        return try await request("/discover/movie", query: items)
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

    // MARK: - Core request

    private func request<T: Decodable>(
        _ path: String,
        query: [URLQueryItem] = [],
        apiKeyOverride: String? = nil
    ) async throws -> T {
        let key = apiKeyOverride ?? apiKeyProvider()
        guard let key, !key.isEmpty else { throw TMDBError.missingAPIKey }

        var components = URLComponents(string: "https://api.themoviedb.org/3" + path)!
        components.queryItems = [URLQueryItem(name: "api_key", value: key)] + query

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: components.url!)
        } catch {
            throw TMDBError.network(underlying: error)
        }

        switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw TMDBError.decoding(underlying: error)
            }
        case 401:
            throw TMDBError.invalidAPIKey
        case 429:
            throw TMDBError.rateLimited
        case let statusCode:
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

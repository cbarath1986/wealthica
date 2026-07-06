import Foundation
import SwiftData
import Combine

@MainActor
final class ForYouViewModel: ObservableObject {
    @Published private(set) var recommendations: [ScoredMovie] = []
    @Published private(set) var newReleases: [TMDBMovie] = []
    @Published private(set) var comingSoon: [TMDBMovie] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isColdStart = false

    private let tmdbClient: TMDBClient

    init(tmdbClient: TMDBClient) {
        self.tmdbClient = tmdbClient
    }

    func refresh(
        library: [Movie],
        preferredLanguages: Set<String>,
        strictLanguageFilter: Bool,
        preferredGenreIDs: Set<Int>,
        strictGenreFilter: Bool,
        dismissedMovieIDs: Set<Int>
    ) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Only movies actually watched or favorited count as taste signal.
        // A watchlist-only entry (saved for later, never watched) shouldn't
        // contribute to genre affinity or suppress the cold-start feed —
        // but it (and anything dismissed via "Not Interested") should still
        // never be re-suggested, so it's folded into `baseExclusions` below.
        let tasteItems = library
            .filter { $0.isWatched || $0.isFavorite }
            .map {
                LibraryItem(
                    tmdbID: $0.tmdbID,
                    genreIDs: $0.genreIDs,
                    isFavorite: $0.isFavorite,
                    referenceDate: $0.favoritedAt ?? $0.watchedAt ?? $0.addedAt
                )
            }
        let baseExclusions = Set(library.map(\.tmdbID)).union(dismissedMovieIDs)

        Log.recommendation.debug("refresh: library=\(library.count, privacy: .public) taste=\(tasteItems.count, privacy: .public) genres=\(preferredGenreIDs.count, privacy: .public) langs=\(preferredLanguages.count, privacy: .public)")

        let languages = preferredLanguages.isEmpty ? [nil as String?] : preferredLanguages.map { $0 }
        let releases = await tmdbClient.newReleasesPages(languages: languages, pageCount: 2)
        newReleases = Array(
            releases
                .filter { !baseExclusions.contains($0.id) }
                .sorted { ($0.releaseDate ?? "") > ($1.releaseDate ?? "") }
                .prefix(15)
        )

        let upcoming = await tmdbClient.comingSoonPages(languages: languages, pageCount: 2)
        comingSoon = Array(
            upcoming
                .filter { !baseExclusions.contains($0.id) }
                .sorted { ($0.releaseDate ?? "9999-99-99") < ($1.releaseDate ?? "9999-99-99") }
                .prefix(15)
        )

        do {
            if tasteItems.isEmpty {
                isColdStart = true
                Log.recommendation.info("cold start: no watched/favorited movies yet, using trending + preferred genres")
                var moviesByID: [Int: TMDBMovie] = [:]
                if let trending = try? await tmdbClient.trending() {
                    for movie in trending.results { moviesByID[movie.id] = movie }
                }
                // With no watch history there's no implicit taste to lean
                // on, so an explicit genre preference is the only signal
                // available to shape the cold-start feed beyond trending.
                if !preferredGenreIDs.isEmpty {
                    let genreIDs = Array(preferredGenreIDs)
                    let discovered = await tmdbClient.discoverPages(genreIDs: genreIDs, languages: languages, pageCount: 3)
                    for movie in discovered where moviesByID[movie.id] == nil {
                        moviesByID[movie.id] = movie
                    }
                    // A niche genre+language combination can still be thin
                    // even across several pages — backfill with the same
                    // languages but no genre restriction so the feed isn't
                    // starved just because that specific combination is rare.
                    if moviesByID.count < 40 {
                        let backfill = await tmdbClient.discoverPages(genreIDs: [], languages: languages, pageCount: 2)
                        for movie in backfill where moviesByID[movie.id] == nil {
                            moviesByID[movie.id] = movie
                        }
                    }
                }
                let candidates = moviesByID.values.map { Candidate(movie: $0, seedHits: 0) }
                recommendations = RecommendationEngine.score(
                    candidates: candidates,
                    library: [],
                    preferredLanguages: preferredLanguages,
                    strictLanguageFilter: false,
                    preferredGenreIDs: preferredGenreIDs,
                    strictGenreFilter: strictGenreFilter,
                    additionalExclusions: baseExclusions,
                    limit: 40
                )
                Log.recommendation.info("cold start: \(candidates.count, privacy: .public) candidates -> \(self.recommendations.count, privacy: .public) recommendations")
                return
            }

            isColdStart = false
            let candidates = try await gatherCandidates(
                library: library,
                libraryItems: tasteItems,
                preferredLanguages: preferredLanguages,
                preferredGenreIDs: preferredGenreIDs
            )
            recommendations = RecommendationEngine.score(
                candidates: candidates,
                library: tasteItems,
                preferredLanguages: preferredLanguages,
                strictLanguageFilter: strictLanguageFilter,
                preferredGenreIDs: preferredGenreIDs,
                strictGenreFilter: strictGenreFilter,
                additionalExclusions: baseExclusions,
                limit: 40
            )
            Log.recommendation.info("personalized: \(candidates.count, privacy: .public) candidates -> \(self.recommendations.count, privacy: .public) recommendations")
        } catch let error as TMDBError {
            Log.recommendation.error("refresh failed: \(error.errorDescription ?? "unknown", privacy: .public)")
            errorMessage = error.errorDescription
        } catch {
            Log.recommendation.error("refresh failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    /// Seeds candidates from each favorite's recommendations/similar list,
    /// then rounds out the pool with a discover query per preferred
    /// language filtered by the user's top genres.
    private func gatherCandidates(
        library: [Movie],
        libraryItems: [LibraryItem],
        preferredLanguages: Set<String>,
        preferredGenreIDs: Set<Int>
    ) async throws -> [Candidate] {
        var seedHitsByID: [Int: Int] = [:]
        var moviesByID: [Int: TMDBMovie] = [:]

        // Extract plain ids on the main actor before crossing into the task
        // group: `Movie` is a main-actor-bound SwiftData model, not Sendable,
        // so it must never be captured directly by a concurrent child task.
        let topFavoriteIDs = library
            .filter(\.isFavorite)
            .sorted { ($0.favoritedAt ?? .distantPast) > ($1.favoritedAt ?? .distantPast) }
            .prefix(5)
            .map(\.tmdbID)

        await withTaskGroup(of: [TMDBMovie].self) { group in
            for favoriteID in topFavoriteIDs {
                group.addTask { [tmdbClient] in
                    if let recommended = try? await tmdbClient.recommendations(for: favoriteID), !recommended.results.isEmpty {
                        return recommended.results
                    }
                    return (try? await tmdbClient.similar(to: favoriteID))?.results ?? []
                }
            }
            for await movies in group {
                for movie in movies {
                    seedHitsByID[movie.id, default: 0] += 1
                    moviesByID[movie.id] = movie
                }
            }
        }

        // Combine genres inferred from watch history with any explicit
        // preference so the discover query reflects both signals.
        let discoverGenres = Array(Set(RecommendationEngine.topGenres(library: libraryItems, count: 4)).union(preferredGenreIDs))
        let languages = preferredLanguages.isEmpty ? [nil as String?] : preferredLanguages.map { $0 }
        let discovered = await tmdbClient.discoverPages(genreIDs: discoverGenres, languages: languages, pageCount: 3)
        for movie in discovered where moviesByID[movie.id] == nil {
            moviesByID[movie.id] = movie
        }

        // A niche genre+language combination can still be thin even across
        // several pages and favorite-seeded candidates — backfill with the
        // same languages but no genre restriction so the feed isn't starved
        // just because that specific combination is rare.
        if moviesByID.count < 40 {
            let backfill = await tmdbClient.discoverPages(genreIDs: [], languages: languages, pageCount: 2)
            for movie in backfill where moviesByID[movie.id] == nil {
                moviesByID[movie.id] = movie
            }
        }

        return moviesByID.values.map { Candidate(movie: $0, seedHits: seedHitsByID[$0.id] ?? 0) }
    }
}

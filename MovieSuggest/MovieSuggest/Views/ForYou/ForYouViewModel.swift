import Foundation
import SwiftData
import Combine

@MainActor
final class ForYouViewModel: ObservableObject {
    @Published private(set) var recommendations: [ScoredMovie] = []
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
        strictGenreFilter: Bool
    ) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let libraryItems = library.map {
            LibraryItem(
                tmdbID: $0.tmdbID,
                genreIDs: $0.genreIDs,
                isFavorite: $0.isFavorite,
                referenceDate: $0.favoritedAt ?? $0.watchedAt ?? $0.addedAt
            )
        }

        do {
            if libraryItems.isEmpty {
                isColdStart = true
                var moviesByID: [Int: TMDBMovie] = [:]
                if let trending = try? await tmdbClient.trending() {
                    for movie in trending.results { moviesByID[movie.id] = movie }
                }
                // With no watch history there's no implicit taste to lean
                // on, so an explicit genre preference is the only signal
                // available to shape the cold-start feed beyond trending.
                if !preferredGenreIDs.isEmpty {
                    let genreIDs = Array(preferredGenreIDs)
                    let languages = preferredLanguages.isEmpty ? [nil as String?] : preferredLanguages.map { $0 }
                    await withTaskGroup(of: [TMDBMovie].self) { group in
                        for language in languages {
                            group.addTask { [tmdbClient] in
                                (try? await tmdbClient.discover(genreIDs: genreIDs, originalLanguage: language))?.results ?? []
                            }
                        }
                        for await movies in group {
                            for movie in movies where moviesByID[movie.id] == nil {
                                moviesByID[movie.id] = movie
                            }
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
                    limit: 30
                )
                return
            }

            isColdStart = false
            let candidates = try await gatherCandidates(
                library: library,
                libraryItems: libraryItems,
                preferredLanguages: preferredLanguages,
                preferredGenreIDs: preferredGenreIDs
            )
            recommendations = RecommendationEngine.score(
                candidates: candidates,
                library: libraryItems,
                preferredLanguages: preferredLanguages,
                strictLanguageFilter: strictLanguageFilter,
                preferredGenreIDs: preferredGenreIDs,
                strictGenreFilter: strictGenreFilter,
                limit: 30
            )
        } catch let error as TMDBError {
            errorMessage = error.errorDescription
        } catch {
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
        let discoverGenres = Array(Set(RecommendationEngine.topGenres(library: libraryItems)).union(preferredGenreIDs))
        let languages = preferredLanguages.isEmpty ? [nil as String?] : preferredLanguages.map { $0 }
        await withTaskGroup(of: [TMDBMovie].self) { group in
            for language in languages {
                group.addTask { [tmdbClient] in
                    (try? await tmdbClient.discover(genreIDs: discoverGenres, originalLanguage: language))?.results ?? []
                }
            }
            for await movies in group {
                for movie in movies where moviesByID[movie.id] == nil {
                    moviesByID[movie.id] = movie
                }
            }
        }

        return moviesByID.values.map { Candidate(movie: $0, seedHits: seedHitsByID[$0.id] ?? 0) }
    }
}

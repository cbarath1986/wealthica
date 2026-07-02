import Foundation
import SwiftData

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

    func refresh(library: [Movie], preferredLanguages: Set<String>, strictLanguageFilter: Bool) async {
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
                let trending = try await tmdbClient.trending()
                let candidates = trending.results.map { Candidate(movie: $0, seedHits: 0) }
                recommendations = RecommendationEngine.score(
                    candidates: candidates,
                    library: [],
                    preferredLanguages: preferredLanguages,
                    strictLanguageFilter: false,
                    limit: 30
                )
                return
            }

            isColdStart = false
            let candidates = try await gatherCandidates(library: library, libraryItems: libraryItems, preferredLanguages: preferredLanguages)
            recommendations = RecommendationEngine.score(
                candidates: candidates,
                library: libraryItems,
                preferredLanguages: preferredLanguages,
                strictLanguageFilter: strictLanguageFilter,
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
        preferredLanguages: Set<String>
    ) async throws -> [Candidate] {
        var seedHitsByID: [Int: Int] = [:]
        var moviesByID: [Int: TMDBMovie] = [:]

        let topFavorites = library
            .filter(\.isFavorite)
            .sorted { ($0.favoritedAt ?? .distantPast) > ($1.favoritedAt ?? .distantPast) }
            .prefix(5)

        await withTaskGroup(of: [TMDBMovie].self) { group in
            for favorite in topFavorites {
                group.addTask { [tmdbClient] in
                    if let recommended = try? await tmdbClient.recommendations(for: favorite.tmdbID), !recommended.results.isEmpty {
                        return recommended.results
                    }
                    return (try? await tmdbClient.similar(to: favorite.tmdbID))?.results ?? []
                }
            }
            for await movies in group {
                for movie in movies {
                    seedHitsByID[movie.id, default: 0] += 1
                    moviesByID[movie.id] = movie
                }
            }
        }

        let topGenres = RecommendationEngine.topGenres(library: libraryItems)
        let languages = preferredLanguages.isEmpty ? [nil as String?] : preferredLanguages.map { $0 }
        await withTaskGroup(of: [TMDBMovie].self) { group in
            for language in languages {
                group.addTask { [tmdbClient] in
                    (try? await tmdbClient.discover(genreIDs: topGenres, originalLanguage: language))?.results ?? []
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

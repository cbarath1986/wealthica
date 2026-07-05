import Foundation
import Combine

/// Powers the "See All" full grid from a movie's detail screen: a much
/// larger pool than the small on-screen rail, ranked by how well each
/// candidate matches the source movie's own genres and TMDB's own
/// recommendations/similar lists — not the user's overall taste profile.
@MainActor
final class MoreLikeThisViewModel: ObservableObject {
    @Published private(set) var results: [ScoredMovie] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let tmdbClient: TMDBClient

    init(tmdbClient: TMDBClient) {
        self.tmdbClient = tmdbClient
    }

    func load(sourceMovie: TMDBMovie, libraryIDs: Set<Int>, preferredLanguages: Set<String>, dismissedMovieIDs: Set<Int>) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var moviesByID: [Int: TMDBMovie] = [:]
        var seedHitsByID: [Int: Int] = [:]

        async let recommendedTask: TMDBPagedResponse<TMDBMovie>? = try? tmdbClient.recommendations(for: sourceMovie.id)
        async let similarTask: TMDBPagedResponse<TMDBMovie>? = try? tmdbClient.similar(to: sourceMovie.id)

        if let recommended = await recommendedTask {
            for movie in recommended.results {
                seedHitsByID[movie.id, default: 0] += 1
                moviesByID[movie.id] = movie
            }
        }
        if let similarResponse = await similarTask {
            for movie in similarResponse.results {
                seedHitsByID[movie.id, default: 0] += 1
                moviesByID[movie.id] = movie
            }
        }

        let genreIDs = sourceMovie.genreIds ?? []
        var languages: [String?] = preferredLanguages.isEmpty ? [nil] : preferredLanguages.map { $0 }
        if let sourceLanguage = sourceMovie.originalLanguage, !languages.contains(sourceLanguage) {
            languages.append(sourceLanguage)
        }

        let discovered = await tmdbClient.discoverPages(genreIDs: genreIDs, languages: languages, pageCount: 4)
        for movie in discovered where moviesByID[movie.id] == nil {
            moviesByID[movie.id] = movie
        }

        let candidates = moviesByID.values.map { Candidate(movie: $0, seedHits: seedHitsByID[$0.id] ?? 0) }

        // No user-taste blending here on purpose — this ranks by similarity
        // to the source movie, not the user's overall library affinity.
        // `preferredGenreIDs` reuses the existing genre-boost scoring term
        // with the source movie's own genres as the target.
        results = RecommendationEngine.score(
            candidates: candidates,
            library: [],
            preferredLanguages: preferredLanguages,
            preferredGenreIDs: Set(genreIDs),
            additionalExclusions: libraryIDs.union(dismissedMovieIDs).union([sourceMovie.id]),
            limit: 50
        )
        Log.recommendation.info("More Like This (\(sourceMovie.id, privacy: .public)): \(candidates.count, privacy: .public) candidates -> \(self.results.count, privacy: .public) results")
    }
}

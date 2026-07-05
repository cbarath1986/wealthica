import Foundation
import SwiftData
import Combine

/// Drives suggestions purely from watch history: genre affinity is built
/// only from movies marked watched (favorites don't get the extra weight
/// they do in For You, and the explicit genre/strict-filter Settings are
/// deliberately not used here), filtered to well-rated candidates.
@MainActor
final class WatchNextViewModel: ObservableObject {
    @Published private(set) var suggestions: [ScoredMovie] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    /// Minimum TMDB rating for a candidate to count as a "good" movie.
    private let qualityThreshold = 6.0

    private let tmdbClient: TMDBClient

    init(tmdbClient: TMDBClient) {
        self.tmdbClient = tmdbClient
    }

    func refresh(library: [Movie], preferredLanguages: Set<String>, dismissedMovieIDs: Set<Int>) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let watchedItems = library
            .filter(\.isWatched)
            .map {
                LibraryItem(
                    tmdbID: $0.tmdbID,
                    genreIDs: $0.genreIDs,
                    isFavorite: false, // equal weighting — no favorite boost here
                    referenceDate: $0.watchedAt ?? $0.addedAt
                )
            }

        guard !watchedItems.isEmpty else {
            suggestions = []
            Log.recommendation.info("Watch Next: no watched movies yet")
            return
        }

        let topGenres = RecommendationEngine.topGenres(library: watchedItems, count: 5)
        Log.recommendation.debug("Watch Next: \(watchedItems.count, privacy: .public) watched movie(s), top genres \(topGenres, privacy: .public)")

        let languages = preferredLanguages.isEmpty ? [nil as String?] : preferredLanguages.map { $0 }
        var movies = await tmdbClient.discoverPages(genreIDs: topGenres, languages: languages, pageCount: 5)

        // A niche genre+language combination can still be thin even across
        // several pages — backfill with the same languages but no genre
        // restriction so the feed isn't starved just because that specific
        // combination is rare.
        if movies.count < 40 {
            let backfill = await tmdbClient.discoverPages(genreIDs: [], languages: languages, pageCount: 3)
            var seen = Set(movies.map(\.id))
            for movie in backfill where !seen.contains(movie.id) {
                movies.append(movie)
                seen.insert(movie.id)
            }
        }

        // "Good movies" — filter to a solid rating bar on top of TMDB's own
        // vote-count floor already applied inside discover().
        let candidates = movies
            .filter { ($0.voteAverage ?? 0) >= qualityThreshold }
            .map { Candidate(movie: $0, seedHits: 0) }

        // Exclude everything already in the library, not just the
        // watched-only subset used to derive genre affinity (so a
        // favorited-but-not-yet-watched or watchlisted movie isn't
        // suggested again), plus anything dismissed via "Not Interested".
        let watchedIDs = Set(watchedItems.map(\.tmdbID))
        let restOfLibraryIDs = Set(library.map(\.tmdbID)).subtracting(watchedIDs)

        suggestions = RecommendationEngine.score(
            candidates: candidates,
            library: watchedItems,
            preferredLanguages: preferredLanguages,
            additionalExclusions: restOfLibraryIDs.union(dismissedMovieIDs),
            limit: 50
        )
        Log.recommendation.info("Watch Next: \(candidates.count, privacy: .public) candidates -> \(self.suggestions.count, privacy: .public) suggestions")
    }
}

import Foundation

/// Deterministic, on-device scorer that ranks candidate movies against the
/// user's watch/favorite history. No networking or persistence — everything
/// it needs arrives as plain structs, which keeps it trivially unit-testable.
enum RecommendationEngine {

    /// Favorites count 3x as much as plain watched movies when building
    /// genre affinity.
    private static let favoriteWeight = 3.0
    private static let watchedWeight = 1.0

    /// Recency half-life-ish decay: a movie from today counts fully,
    /// one from ~180 days ago counts ~68%, and old taste never fully
    /// disappears (floor of 0.5).
    private static func recencyMultiplier(referenceDate: Date, now: Date) -> Double {
        let days = max(0, now.timeIntervalSince(referenceDate) / 86400)
        return 0.5 + 0.5 * exp(-days / 180)
    }

    /// Normalized genre affinity in [0, 1], keyed by TMDB genre id.
    static func genreAffinity(library: [LibraryItem], now: Date = .now) -> [Int: Double] {
        var affinity: [Int: Double] = [:]
        for item in library {
            let weight = (item.isFavorite ? favoriteWeight : watchedWeight)
                * recencyMultiplier(referenceDate: item.referenceDate, now: now)
            for genreID in item.genreIDs {
                affinity[genreID, default: 0] += weight
            }
        }
        guard let maxValue = affinity.values.max(), maxValue > 0 else { return [:] }
        return affinity.mapValues { $0 / maxValue }
    }

    /// Scores and ranks candidates. `watchedIDs` are hard-excluded from the
    /// result regardless of score. Ties break by popularity, then id, so
    /// output is fully deterministic for a given input.
    static func score(
        candidates: [Candidate],
        library: [LibraryItem],
        preferredLanguages: Set<String>,
        strictLanguageFilter: Bool = false,
        now: Date = .now,
        limit: Int = 30
    ) -> [ScoredMovie] {
        let excludedIDs = Set(library.map(\.tmdbID))
        let affinity = genreAffinity(library: library, now: now)

        let scored: [ScoredMovie] = candidates.compactMap { candidate in
            guard !excludedIDs.contains(candidate.movie.id) else { return nil }

            let genreIDs = candidate.movie.genreIds ?? []
            let matchesLanguage = candidate.movie.originalLanguage
                .map { preferredLanguages.contains($0) } ?? false

            if strictLanguageFilter && !matchesLanguage { return nil }

            let genreScores = genreIDs.compactMap { affinity[$0] }
            let genreScore = genreScores.isEmpty ? 0 : genreScores.reduce(0, +) / Double(genreScores.count)
            let seedScore = min(1.0, 0.5 * Double(candidate.seedHits))
            let languageScore = matchesLanguage ? 1.0 : 0.0
            let qualityScore = min(1.0, max(0.0, (candidate.movie.voteAverage ?? 0) / 10))

            let total = 0.45 * genreScore
                + 0.25 * seedScore
                + 0.20 * languageScore
                + 0.10 * qualityScore

            let topGenreID = genreIDs.max { (affinity[$0] ?? 0) < (affinity[$1] ?? 0) }

            return ScoredMovie(movie: candidate.movie, total: total, topGenreID: topGenreID, fromSeed: candidate.seedHits > 0)
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.total != rhs.total { return lhs.total > rhs.total }
                let lhsPopularity = lhs.movie.popularity ?? 0
                let rhsPopularity = rhs.movie.popularity ?? 0
                if lhsPopularity != rhsPopularity { return lhsPopularity > rhsPopularity }
                return lhs.movie.id < rhs.movie.id
            }
            .prefix(limit)
            .map { $0 }
    }

    /// Top genre ids by affinity, for building `/discover` queries.
    static func topGenres(library: [LibraryItem], now: Date = .now, count: Int = 3) -> [Int] {
        let affinity = genreAffinity(library: library, now: now)
        return affinity.sorted { $0.value > $1.value }.prefix(count).map(\.key)
    }
}

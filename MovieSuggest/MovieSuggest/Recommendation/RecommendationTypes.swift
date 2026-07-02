import Foundation

/// A movie already in the user's library (watched and/or favorite),
/// reduced to the fields the scorer needs. Pure struct — no SwiftData
/// import — so `RecommendationEngine` stays framework-free and testable.
struct LibraryItem {
    let tmdbID: Int
    let genreIDs: [Int]
    let isFavorite: Bool
    /// Most relevant interaction date: favoritedAt, else watchedAt, else addedAt.
    let referenceDate: Date
}

/// A movie fetched from TMDB that is eligible to be recommended.
struct Candidate {
    let movie: TMDBMovie
    /// Number of distinct favorite "seeds" whose recommendations/similar
    /// list this candidate appeared in.
    let seedHits: Int
}

/// A candidate after scoring, with the breakdown kept so views can show
/// a human-readable "why" caption.
struct ScoredMovie: Identifiable {
    let movie: TMDBMovie
    let total: Double
    let topGenreID: Int?
    let fromSeed: Bool

    var id: Int { movie.id }
}

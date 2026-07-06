import Foundation

/// A portable snapshot of everything that isn't recoverable from TMDB
/// alone: your library records and preferences. Deliberately excludes the
/// TMDB API key — that's a credential, not data, and shouldn't end up in a
/// file you might share or store in iCloud Drive/email.
struct LibraryBackup: Codable {
    struct MovieRecord: Codable {
        let tmdbID: Int
        let title: String
        let overview: String
        let posterPath: String?
        let releaseDate: Date?
        let genreIDs: [Int]
        let originalLanguage: String
        let voteAverage: Double
        let isWatched: Bool
        let isFavorite: Bool
        let isWatchlisted: Bool
        let watchedAt: Date?
        let favoritedAt: Date?
        let watchlistedAt: Date?
        let addedAt: Date
    }

    let exportedAt: Date
    let movies: [MovieRecord]
    let preferredLanguages: [String]
    let preferredGenreIDs: [Int]
    let dismissedMovieIDs: [Int]
}

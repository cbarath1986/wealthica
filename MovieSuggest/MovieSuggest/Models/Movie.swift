import Foundation
import SwiftData

/// A movie the user has interacted with (watched and/or favorited).
/// Only these are persisted — search results and recommendations stay
/// in memory as DTOs.
@Model
final class Movie {
    @Attribute(.unique) var tmdbID: Int
    var title: String
    var overview: String
    var posterPath: String?
    var releaseDate: Date?
    var genreIDs: [Int]
    var originalLanguage: String
    var voteAverage: Double
    var isWatched: Bool
    var isFavorite: Bool
    var isWatchlisted: Bool = false
    var watchedAt: Date?
    var favoritedAt: Date?
    var watchlistedAt: Date?
    var addedAt: Date

    init(dto: TMDBMovie) {
        tmdbID = dto.id
        title = dto.title
        overview = dto.overview ?? ""
        posterPath = dto.posterPath
        releaseDate = dto.releaseDate.flatMap { Movie.releaseDateFormatter.date(from: $0) }
        genreIDs = dto.genreIds ?? []
        originalLanguage = dto.originalLanguage ?? ""
        voteAverage = dto.voteAverage ?? 0
        isWatched = false
        isFavorite = false
        isWatchlisted = false
        addedAt = .now
    }

    /// Restores a record from a backup — unlike `init(dto:)`, this carries
    /// over the actual watched/favorite/watchlist state and timestamps.
    init(record: LibraryBackup.MovieRecord) {
        tmdbID = record.tmdbID
        title = record.title
        overview = record.overview
        posterPath = record.posterPath
        releaseDate = record.releaseDate
        genreIDs = record.genreIDs
        originalLanguage = record.originalLanguage
        voteAverage = record.voteAverage
        isWatched = record.isWatched
        isFavorite = record.isFavorite
        isWatchlisted = record.isWatchlisted
        watchedAt = record.watchedAt
        favoritedAt = record.favoritedAt
        watchlistedAt = record.watchlistedAt
        addedAt = record.addedAt
    }

    /// Applies a backup record's state onto an existing row (used when
    /// restoring over a movie that's already in the library).
    func apply(_ record: LibraryBackup.MovieRecord) {
        title = record.title
        overview = record.overview
        posterPath = record.posterPath
        releaseDate = record.releaseDate
        genreIDs = record.genreIDs
        originalLanguage = record.originalLanguage
        voteAverage = record.voteAverage
        isWatched = record.isWatched
        isFavorite = record.isFavorite
        isWatchlisted = record.isWatchlisted
        watchedAt = record.watchedAt
        favoritedAt = record.favoritedAt
        watchlistedAt = record.watchlistedAt
    }

    var backupRecord: LibraryBackup.MovieRecord {
        LibraryBackup.MovieRecord(
            tmdbID: tmdbID,
            title: title,
            overview: overview,
            posterPath: posterPath,
            releaseDate: releaseDate,
            genreIDs: genreIDs,
            originalLanguage: originalLanguage,
            voteAverage: voteAverage,
            isWatched: isWatched,
            isFavorite: isFavorite,
            isWatchlisted: isWatchlisted,
            watchedAt: watchedAt,
            favoritedAt: favoritedAt,
            watchlistedAt: watchlistedAt,
            addedAt: addedAt
        )
    }

    var releaseYear: String? {
        releaseDate.map { String(Calendar.current.component(.year, from: $0)) }
    }

    /// DTO view of this record so library movies and API results can share
    /// the same detail screen and row components.
    var asDTO: TMDBMovie {
        TMDBMovie(
            id: tmdbID,
            title: title,
            overview: overview,
            posterPath: posterPath,
            backdropPath: nil,
            releaseDate: releaseDate.map { Movie.releaseDateFormatter.string(from: $0) },
            genreIds: genreIDs,
            originalLanguage: originalLanguage.isEmpty ? nil : originalLanguage,
            voteAverage: voteAverage,
            voteCount: nil,
            popularity: nil
        )
    }

    func toggleWatched() {
        isWatched.toggle()
        watchedAt = isWatched ? .now : nil
        // Once watched, there's nothing left to "watch later" for.
        if isWatched && isWatchlisted {
            isWatchlisted = false
            watchlistedAt = nil
        }
    }

    func toggleFavorite() {
        isFavorite.toggle()
        favoritedAt = isFavorite ? .now : nil
    }

    func toggleWatchlisted() {
        isWatchlisted.toggle()
        watchlistedAt = isWatchlisted ? .now : nil
    }

    static let releaseDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    static func find(tmdbID: Int, in context: ModelContext) -> Movie? {
        var descriptor = FetchDescriptor<Movie>(predicate: #Predicate { $0.tmdbID == tmdbID })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}

extension ModelContext {
    /// Fetches or creates the library record for a movie, applies `change`,
    /// and removes the record if it ends up neither watched nor favorite.
    func updateLibrary(for dto: TMDBMovie, change: (Movie) -> Void) {
        let movie: Movie
        if let existing = Movie.find(tmdbID: dto.id, in: self) {
            movie = existing
        } else {
            movie = Movie(dto: dto)
            insert(movie)
        }
        change(movie)
        if !movie.isWatched && !movie.isFavorite && !movie.isWatchlisted {
            Log.library.info("removed \"\(movie.title, privacy: .public)\" (tmdbID \(movie.tmdbID, privacy: .public)) from library")
            delete(movie)
        } else {
            Log.library.info("\"\(movie.title, privacy: .public)\" (tmdbID \(movie.tmdbID, privacy: .public)): watched=\(movie.isWatched, privacy: .public) favorite=\(movie.isFavorite, privacy: .public) watchlisted=\(movie.isWatchlisted, privacy: .public)")
        }
    }
}

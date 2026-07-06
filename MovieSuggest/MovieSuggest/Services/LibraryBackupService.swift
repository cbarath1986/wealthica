import Foundation
import SwiftData

enum LibraryBackupError: LocalizedError {
    case invalidFile

    var errorDescription: String? {
        switch self {
        case .invalidFile:
            return "This file doesn't look like a MovieSuggest backup."
        }
    }
}

enum LibraryBackupService {
    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    @MainActor
    static func export(movies: [Movie], settingsStore: SettingsStore) -> Data? {
        let backup = LibraryBackup(
            exportedAt: .now,
            movies: movies.map(\.backupRecord),
            preferredLanguages: Array(settingsStore.preferredLanguages),
            preferredGenreIDs: Array(settingsStore.preferredGenreIDs),
            dismissedMovieIDs: Array(settingsStore.dismissedMovieIDs)
        )
        return try? makeEncoder().encode(backup)
    }

    /// Upserts by tmdbID — a movie already in the library gets its state
    /// overwritten by the backup's version; anything in the current
    /// library but absent from the backup is left untouched (this restores
    /// on top of, rather than replacing, what's already there). Preference
    /// sets (languages/genres/dismissed) are replaced outright, since those
    /// aren't naturally mergeable. Returns the number of movie records
    /// processed, for a confirmation message.
    @MainActor
    @discardableResult
    static func restore(from data: Data, context: ModelContext, settingsStore: SettingsStore) throws -> Int {
        let backup: LibraryBackup
        do {
            backup = try makeDecoder().decode(LibraryBackup.self, from: data)
        } catch {
            throw LibraryBackupError.invalidFile
        }

        for record in backup.movies {
            if let existing = Movie.find(tmdbID: record.tmdbID, in: context) {
                existing.apply(record)
            } else {
                context.insert(Movie(record: record))
            }
        }

        settingsStore.preferredLanguages = Set(backup.preferredLanguages)
        settingsStore.preferredGenreIDs = Set(backup.preferredGenreIDs)
        settingsStore.restore(dismissedMovieIDs: Set(backup.dismissedMovieIDs))

        return backup.movies.count
    }
}

import Foundation
import Combine

/// User-facing preferences, backed by UserDefaults. Kept separate from
/// SwiftData since these are simple scalars/sets, not persisted records.
@MainActor
final class SettingsStore: ObservableObject {
    private enum Keys {
        static let preferredLanguages = "preferredLanguages"
        static let strictLanguageFilter = "strictLanguageFilter"
        static let preferredGenreIDs = "preferredGenreIDs"
        static let strictGenreFilter = "strictGenreFilter"
        static let dismissedMovieIDs = "dismissedMovieIDs"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let isAIMoodSearchEnabled = "isAIMoodSearchEnabled"
    }

    private let defaults: UserDefaults

    @Published var preferredLanguages: Set<String> {
        didSet { defaults.set(Array(preferredLanguages), forKey: Keys.preferredLanguages) }
    }

    @Published var strictLanguageFilter: Bool {
        didSet { defaults.set(strictLanguageFilter, forKey: Keys.strictLanguageFilter) }
    }

    /// Empty means "no explicit genre preference" — recommendations fall
    /// back to genre affinity inferred from watch history alone.
    @Published var preferredGenreIDs: Set<Int> {
        didSet { defaults.set(Array(preferredGenreIDs), forKey: Keys.preferredGenreIDs) }
    }

    @Published var strictGenreFilter: Bool {
        didSet { defaults.set(strictGenreFilter, forKey: Keys.strictGenreFilter) }
    }

    /// Movies dismissed via "Not Interested" — excluded from every feed's
    /// candidate pool (not just filtered at render time), so a dismissal
    /// doesn't silently eat into a feed's result limit.
    @Published private(set) var dismissedMovieIDs: Set<Int> {
        didSet { defaults.set(Array(dismissedMovieIDs), forKey: Keys.dismissedMovieIDs) }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    /// User-facing preference only — whether AI mood search is actually
    /// usable also depends on `AIMoodAvailability.current` (device/OS
    /// capability), which this store knows nothing about.
    @Published var isAIMoodSearchEnabled: Bool {
        didSet { defaults.set(isAIMoodSearchEnabled, forKey: Keys.isAIMoodSearchEnabled) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let saved = defaults.array(forKey: Keys.preferredLanguages) as? [String], !saved.isEmpty {
            preferredLanguages = Set(saved)
        } else {
            preferredLanguages = [Language.deviceDefault]
        }
        strictLanguageFilter = defaults.bool(forKey: Keys.strictLanguageFilter)
        preferredGenreIDs = Set(defaults.array(forKey: Keys.preferredGenreIDs) as? [Int] ?? [])
        strictGenreFilter = defaults.bool(forKey: Keys.strictGenreFilter)
        dismissedMovieIDs = Set(defaults.array(forKey: Keys.dismissedMovieIDs) as? [Int] ?? [])
        hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        isAIMoodSearchEnabled = defaults.object(forKey: Keys.isAIMoodSearchEnabled) as? Bool ?? true
    }

    func dismiss(_ movieID: Int) {
        dismissedMovieIDs.insert(movieID)
    }

    func undismiss(_ movieID: Int) {
        dismissedMovieIDs.remove(movieID)
    }

    /// Bulk-replaces the dismissed set — used when restoring a backup.
    func restore(dismissedMovieIDs: Set<Int>) {
        self.dismissedMovieIDs = dismissedMovieIDs
    }
}

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
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
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

    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
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
        hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
    }
}

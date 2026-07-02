import Foundation
import Combine

/// User-facing preferences, backed by UserDefaults. Kept separate from
/// SwiftData since these are simple scalars/sets, not persisted records.
@MainActor
final class SettingsStore: ObservableObject {
    private enum Keys {
        static let preferredLanguages = "preferredLanguages"
        static let strictLanguageFilter = "strictLanguageFilter"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    private let defaults: UserDefaults

    @Published var preferredLanguages: Set<String> {
        didSet { defaults.set(Array(preferredLanguages), forKey: Keys.preferredLanguages) }
    }

    @Published var strictLanguageFilter: Bool {
        didSet { defaults.set(strictLanguageFilter, forKey: Keys.strictLanguageFilter) }
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
        hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
    }
}

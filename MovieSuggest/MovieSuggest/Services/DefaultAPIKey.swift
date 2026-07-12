import Foundation

/// Optional built-in TMDB API key, for App Store distribution.
///
/// Leave empty for development — the app then asks each user for their own
/// key during onboarding (the original bring-your-own-key flow). Before an
/// App Store/TestFlight build, paste your TMDB key here: onboarding skips
/// the key screen entirely and users never have to know TMDB exists.
/// A user can still override it with a personal key in Settings.
///
/// Note: anything compiled into an app binary can be extracted by a
/// determined user, so treat this as a low-stakes convenience for a free,
/// non-commercial app — never reuse a key you care about elsewhere.
enum DefaultAPIKey {
    static let key = ""

    static var isConfigured: Bool { !key.isEmpty }
}

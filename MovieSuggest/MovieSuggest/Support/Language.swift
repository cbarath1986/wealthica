import Foundation

/// A curated set of ISO 639-1 languages, biased toward TMDB's most common
/// `original_language` values plus major world languages.
struct Language: Identifiable, Hashable {
    let code: String
    let englishName: String
    let nativeName: String

    var id: String { code }

    var displayName: String {
        englishName == nativeName ? englishName : "\(englishName) (\(nativeName))"
    }

    static let all: [Language] = [
        Language(code: "en", englishName: "English", nativeName: "English"),
        Language(code: "es", englishName: "Spanish", nativeName: "Español"),
        Language(code: "fr", englishName: "French", nativeName: "Français"),
        Language(code: "de", englishName: "German", nativeName: "Deutsch"),
        Language(code: "it", englishName: "Italian", nativeName: "Italiano"),
        Language(code: "pt", englishName: "Portuguese", nativeName: "Português"),
        Language(code: "nl", englishName: "Dutch", nativeName: "Nederlands"),
        Language(code: "sv", englishName: "Swedish", nativeName: "Svenska"),
        Language(code: "no", englishName: "Norwegian", nativeName: "Norsk"),
        Language(code: "da", englishName: "Danish", nativeName: "Dansk"),
        Language(code: "fi", englishName: "Finnish", nativeName: "Suomi"),
        Language(code: "pl", englishName: "Polish", nativeName: "Polski"),
        Language(code: "ru", englishName: "Russian", nativeName: "Русский"),
        Language(code: "uk", englishName: "Ukrainian", nativeName: "Українська"),
        Language(code: "el", englishName: "Greek", nativeName: "Ελληνικά"),
        Language(code: "tr", englishName: "Turkish", nativeName: "Türkçe"),
        Language(code: "he", englishName: "Hebrew", nativeName: "עברית"),
        Language(code: "ar", englishName: "Arabic", nativeName: "العربية"),
        Language(code: "fa", englishName: "Persian", nativeName: "فارسی"),
        Language(code: "hi", englishName: "Hindi", nativeName: "हिन्दी"),
        Language(code: "bn", englishName: "Bengali", nativeName: "বাংলা"),
        Language(code: "ta", englishName: "Tamil", nativeName: "தமிழ்"),
        Language(code: "te", englishName: "Telugu", nativeName: "తెలుగు"),
        Language(code: "ur", englishName: "Urdu", nativeName: "اردو"),
        Language(code: "th", englishName: "Thai", nativeName: "ภาษาไทย"),
        Language(code: "vi", englishName: "Vietnamese", nativeName: "Tiếng Việt"),
        Language(code: "id", englishName: "Indonesian", nativeName: "Bahasa Indonesia"),
        Language(code: "ms", englishName: "Malay", nativeName: "Bahasa Melayu"),
        Language(code: "tl", englishName: "Filipino", nativeName: "Filipino"),
        Language(code: "zh", englishName: "Chinese", nativeName: "中文"),
        Language(code: "ja", englishName: "Japanese", nativeName: "日本語"),
        Language(code: "ko", englishName: "Korean", nativeName: "한국어"),
        Language(code: "cs", englishName: "Czech", nativeName: "Čeština"),
        Language(code: "hu", englishName: "Hungarian", nativeName: "Magyar"),
        Language(code: "ro", englishName: "Romanian", nativeName: "Română"),
        Language(code: "sk", englishName: "Slovak", nativeName: "Slovenčina"),
        Language(code: "bg", englishName: "Bulgarian", nativeName: "Български"),
        Language(code: "hr", englishName: "Croatian", nativeName: "Hrvatski"),
        Language(code: "sr", englishName: "Serbian", nativeName: "Српски"),
        Language(code: "is", englishName: "Icelandic", nativeName: "Íslenska"),
        Language(code: "sw", englishName: "Swahili", nativeName: "Kiswahili"),
    ]

    static func named(_ code: String) -> Language? {
        all.first { $0.code == code }
    }

    /// Best-effort language code derived from the device locale, used to
    /// pre-select onboarding.
    static var deviceDefault: String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }
}

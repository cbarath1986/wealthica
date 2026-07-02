import Foundation

/// Builds TMDB image URLs. Sizes are from TMDB's documented stable set,
/// so the /configuration endpoint isn't needed.
enum TMDBImage {
    private static let base = "https://image.tmdb.org/t/p/"

    static func poster(_ path: String?) -> URL? { url(path, size: "w342") }
    static func thumbnail(_ path: String?) -> URL? { url(path, size: "w154") }
    static func backdrop(_ path: String?) -> URL? { url(path, size: "w780") }

    private static func url(_ path: String?, size: String) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return URL(string: base + size + path)
    }
}

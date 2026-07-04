import Foundation
import Combine

/// Caches the TMDB genre id -> name map. Fetched once per app run (and
/// persisted to UserDefaults so cold launches have names immediately).
@MainActor
final class GenreStore: ObservableObject {
    private static let cacheKey = "cachedGenres"

    @Published private(set) var namesByID: [Int: String] = [:]
    /// All genres, alphabetized, for use in a picker UI.
    @Published private(set) var genres: [TMDBGenre] = []

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let cached = defaults.dictionary(forKey: Self.cacheKey) as? [String: String] {
            let mapping = Dictionary(uniqueKeysWithValues: cached.compactMap { key, value in
                Int(key).map { ($0, value) }
            })
            namesByID = mapping
            genres = mapping.map { TMDBGenre(id: $0.key, name: $0.value) }.sorted { $0.name < $1.name }
        }
    }

    func name(for genreID: Int) -> String? {
        namesByID[genreID]
    }

    func names(for genreIDs: [Int]) -> [String] {
        genreIDs.compactMap { namesByID[$0] }
    }

    func refresh(using client: TMDBClient) async {
        guard let fetched = try? await client.genres() else {
            Log.app.error("GenreStore: refresh failed, keeping cached \(self.namesByID.count, privacy: .public) genre(s)")
            return
        }
        var mapping: [Int: String] = [:]
        for genre in fetched { mapping[genre.id] = genre.name }
        namesByID = mapping
        genres = fetched.sorted { $0.name < $1.name }
        let stringKeyed = Dictionary(uniqueKeysWithValues: mapping.map { (String($0.key), $0.value) })
        defaults.set(stringKeyed, forKey: Self.cacheKey)
        Log.app.info("GenreStore: refreshed \(fetched.count, privacy: .public) genres")
    }
}

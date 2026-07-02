import Foundation
import Combine

/// Caches the TMDB genre id -> name map. Fetched once per app run (and
/// persisted to UserDefaults so cold launches have names immediately).
@MainActor
final class GenreStore: ObservableObject {
    private static let cacheKey = "cachedGenres"

    @Published private(set) var namesByID: [Int: String] = [:]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let cached = defaults.dictionary(forKey: Self.cacheKey) as? [String: String] {
            namesByID = Dictionary(uniqueKeysWithValues: cached.compactMap { key, value in
                Int(key).map { ($0, value) }
            })
        }
    }

    func name(for genreID: Int) -> String? {
        namesByID[genreID]
    }

    func names(for genreIDs: [Int]) -> [String] {
        genreIDs.compactMap { namesByID[$0] }
    }

    func refresh(using client: TMDBClient) async {
        guard let genres = try? await client.genres() else { return }
        var mapping: [Int: String] = [:]
        for genre in genres { mapping[genre.id] = genre.name }
        namesByID = mapping
        let stringKeyed = Dictionary(uniqueKeysWithValues: mapping.map { (String($0.key), $0.value) })
        defaults.set(stringKeyed, forKey: Self.cacheKey)
    }
}

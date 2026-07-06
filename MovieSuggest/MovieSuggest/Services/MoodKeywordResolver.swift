import Foundation

/// Resolves human-readable keyword names (e.g. "feel-good") to TMDB's
/// internal numeric keyword ids via `/search/keyword`, caching results so
/// repeated mood searches don't re-hit the network for names already seen
/// this app run.
actor MoodKeywordResolver {
    private let tmdbClient: TMDBClient
    private var cache: [String: Int] = [:]

    init(tmdbClient: TMDBClient) {
        self.tmdbClient = tmdbClient
    }

    /// Resolves every name in `names` to a TMDB keyword id, silently
    /// skipping any that don't resolve (TMDB's keyword search occasionally
    /// comes up empty for very niche phrasing) — callers should treat an
    /// empty result as "couldn't search this mood" rather than an error.
    func resolveIDs(for names: [String]) async -> [Int] {
        var ids: [Int] = []
        for name in names {
            if let cached = cache[name] {
                ids.append(cached)
                continue
            }
            guard let results = try? await tmdbClient.searchKeyword(query: name), !results.isEmpty else {
                continue
            }
            let best = results.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) ?? results[0]
            cache[name] = best.id
            ids.append(best.id)
        }
        return ids
    }
}

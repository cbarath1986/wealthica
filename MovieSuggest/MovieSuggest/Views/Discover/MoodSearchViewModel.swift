import Foundation
import Combine
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Drives mood-based browsing: either a tap on a curated `MoodTag` chip, or
/// (when Apple Intelligence is available and enabled) a free-text mood
/// description parsed on-device. Both paths funnel into the same
/// keyword/genre `discoverPages` search, so results, loading, and error
/// state are unified regardless of which entry point was used.
@MainActor
final class MoodSearchViewModel: ObservableObject {
    @Published private(set) var results: [TMDBMovie] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var selectedMood: MoodTag?
    @Published private(set) var aiQueryText: String?

    private let tmdbClient: TMDBClient
    private let resolver: MoodKeywordResolver

    init(tmdbClient: TMDBClient) {
        self.tmdbClient = tmdbClient
        self.resolver = MoodKeywordResolver(tmdbClient: tmdbClient)
    }

    var isActive: Bool { selectedMood != nil || aiQueryText != nil }

    func select(_ mood: MoodTag, preferredLanguages: Set<String>, dismissedMovieIDs: Set<Int>) async {
        selectedMood = mood
        aiQueryText = nil
        await runSearch(keywordNames: mood.keywordNames, genreIDs: [], preferredLanguages: preferredLanguages, dismissedMovieIDs: dismissedMovieIDs)
    }

    func clear() {
        selectedMood = nil
        aiQueryText = nil
        results = []
        errorMessage = nil
    }

    #if canImport(FoundationModels)
    /// Free-text mood search via Apple Intelligence's on-device model.
    /// Callers must already have confirmed `AIMoodAvailability.current` is
    /// `.available` and that the user has the feature enabled — this method
    /// doesn't re-check either, since it's only ever wired to UI that's
    /// hidden without both.
    @available(iOS 26.0, *)
    func searchFreeText(_ text: String, genreStore: GenreStore, preferredLanguages: Set<String>, dismissedMovieIDs: Set<Int>) async {
        selectedMood = nil
        aiQueryText = text
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let parsed = try await AIMoodQueryService().parseMood(text)
            let genreIDs = genreStore.genres
                .filter { genre in parsed.genreNames.contains { $0.caseInsensitiveCompare(genre.name) == .orderedSame } }
                .map(\.id)
            await runSearch(keywordNames: parsed.keywords, genreIDs: genreIDs, preferredLanguages: preferredLanguages, dismissedMovieIDs: dismissedMovieIDs)
        } catch {
            results = []
            errorMessage = "Couldn't understand that mood. Try rephrasing, or pick a mood tag below."
            Log.network.error("AI mood search failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    #endif

    private func runSearch(keywordNames: [String], genreIDs: [Int], preferredLanguages: Set<String>, dismissedMovieIDs: Set<Int>) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let keywordIDs = await resolver.resolveIDs(for: keywordNames)
        guard !keywordIDs.isEmpty || !genreIDs.isEmpty else {
            results = []
            errorMessage = "Couldn't find movies for that mood right now."
            Log.network.error("Mood search: no keyword/genre ids resolved")
            return
        }
        let languages: [String?] = preferredLanguages.isEmpty ? [nil] : Array(preferredLanguages)
        let movies = await tmdbClient.discoverPages(genreIDs: genreIDs, languages: languages, pageCount: 1, keywordIDs: keywordIDs)
        results = movies
            .filter { !dismissedMovieIDs.contains($0.id) }
            .sorted { ($0.popularity ?? 0) > ($1.popularity ?? 0) }
        Log.network.debug("Mood search -> \(self.results.count, privacy: .public) results")
    }
}

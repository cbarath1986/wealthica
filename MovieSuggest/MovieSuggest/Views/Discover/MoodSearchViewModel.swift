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
    /// Cancelled and replaced on every new mood/AI search so a slow, stale
    /// request (e.g. mood A's network round-trip finishing after mood B's)
    /// can never overwrite fresher results.
    private var searchTask: Task<Void, Never>?

    init(tmdbClient: TMDBClient) {
        self.tmdbClient = tmdbClient
        self.resolver = MoodKeywordResolver(tmdbClient: tmdbClient)
    }

    var isActive: Bool { selectedMood != nil || aiQueryText != nil }

    func select(_ mood: MoodTag, preferredLanguages: Set<String>, dismissedMovieIDs: Set<Int>) {
        searchTask?.cancel()
        selectedMood = mood
        aiQueryText = nil
        searchTask = Task {
            await runSearch(keywordNames: mood.keywordNames, genreIDs: [], preferredLanguages: preferredLanguages, dismissedMovieIDs: dismissedMovieIDs)
        }
    }

    func clear() {
        searchTask?.cancel()
        searchTask = nil
        selectedMood = nil
        aiQueryText = nil
        results = []
        errorMessage = nil
    }

    /// Removes a just-dismissed ("Not Interested") movie from the visible
    /// results immediately, regardless of whether they came from a mood
    /// chip or an AI free-text search — no re-fetch needed, and it can't
    /// race with `searchTask`.
    func removeDismissed(_ movieID: Int) {
        results.removeAll { $0.id == movieID }
    }

    #if canImport(FoundationModels)
    /// Free-text mood search via Apple Intelligence's on-device model.
    /// Callers must already have confirmed `AIMoodAvailability.current` is
    /// `.available` and that the user has the feature enabled — this method
    /// doesn't re-check either, since it's only ever wired to UI that's
    /// hidden without both.
    @available(iOS 26.0, *)
    func searchFreeText(_ text: String, genreStore: GenreStore, preferredLanguages: Set<String>, dismissedMovieIDs: Set<Int>) {
        searchTask?.cancel()
        selectedMood = nil
        aiQueryText = text
        searchTask = Task {
            isLoading = true
            errorMessage = nil
            do {
                let parsed = try await AIMoodQueryService().parseMood(text)
                guard !Task.isCancelled else { return }
                let genreIDs = genreStore.genres
                    .filter { genre in parsed.genreNames.contains { $0.caseInsensitiveCompare(genre.name) == .orderedSame } }
                    .map(\.id)
                await runSearch(keywordNames: parsed.keywords, genreIDs: genreIDs, preferredLanguages: preferredLanguages, dismissedMovieIDs: dismissedMovieIDs)
                guard !Task.isCancelled else { return }
                // The AI's keywords/genre names are free-form and TMDB's
                // keyword search is a literal text match over its own fixed
                // vocabulary, so a perfectly reasonable mood description can
                // still resolve to zero keyword/genre ids (or ids that just
                // have no matching movies). Rather than dead-end there, fall
                // back to a plain TMDB title/overview search on the user's
                // original text so a request essentially never comes back
                // completely empty.
                if results.isEmpty {
                    await fallbackTextSearch(text, dismissedMovieIDs: dismissedMovieIDs)
                }
            } catch {
                guard !Task.isCancelled else { return }
                isLoading = false
                results = []
                errorMessage = "Couldn't understand that mood. Try rephrasing, or pick a mood tag below."
                Log.network.error("AI mood search failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    #endif

    private func runSearch(keywordNames: [String], genreIDs: [Int], preferredLanguages: Set<String>, dismissedMovieIDs: Set<Int>) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let keywordIDs = await resolver.resolveIDs(for: keywordNames)
        guard !Task.isCancelled else { return }
        guard !keywordIDs.isEmpty || !genreIDs.isEmpty else {
            results = []
            errorMessage = "Couldn't find movies for that mood right now."
            Log.network.error("Mood search: no keyword/genre ids resolved")
            return
        }
        let languages: [String?] = preferredLanguages.isEmpty ? [nil] : Array(preferredLanguages)
        let movies = await tmdbClient.discoverPages(genreIDs: genreIDs, languages: languages, pageCount: 1, keywordIDs: keywordIDs)
        guard !Task.isCancelled else { return }
        results = movies
            .filter { !dismissedMovieIDs.contains($0.id) }
            .sorted { ($0.popularity ?? 0) > ($1.popularity ?? 0) }
        Log.network.debug("Mood search -> \(self.results.count, privacy: .public) results")
    }

    private func fallbackTextSearch(_ text: String, dismissedMovieIDs: Set<Int>) async {
        isLoading = true
        defer { isLoading = false }
        guard let response = try? await tmdbClient.searchMovies(query: text) else { return }
        guard !Task.isCancelled else { return }
        let filtered = response.results.filter { !dismissedMovieIDs.contains($0.id) }
        guard !filtered.isEmpty else { return }
        results = filtered
        errorMessage = nil
        Log.network.debug("Mood search: keyword/genre resolution came up empty, fell back to text search -> \(filtered.count, privacy: .public) results")
    }
}

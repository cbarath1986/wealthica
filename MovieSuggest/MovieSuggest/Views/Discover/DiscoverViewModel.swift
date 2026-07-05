import Foundation
import Combine

@MainActor
final class DiscoverViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var results: [TMDBMovie] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let tmdbClient: TMDBClient
    private var searchTask: Task<Void, Never>?

    init(tmdbClient: TMDBClient) {
        self.tmdbClient = tmdbClient
    }

    /// Called on every keystroke; debounces so we don't hammer TMDB while
    /// the user is still typing.
    func queryChanged(dismissedMovieIDs: Set<Int>) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = nil
        guard !trimmed.isEmpty else {
            searchTask = Task { await loadTrending(dismissedMovieIDs: dismissedMovieIDs) }
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await search(trimmed, dismissedMovieIDs: dismissedMovieIDs)
        }
    }

    func loadTrendingIfNeeded(dismissedMovieIDs: Set<Int>) async {
        guard results.isEmpty, query.isEmpty else { return }
        await loadTrending(dismissedMovieIDs: dismissedMovieIDs)
    }

    private func loadTrending(dismissedMovieIDs: Set<Int>) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await tmdbClient.trending()
            results = response.results.filter { !dismissedMovieIDs.contains($0.id) }
            errorMessage = nil
            Log.network.debug("Discover: trending loaded \(response.results.count, privacy: .public) movies")
        } catch let error as TMDBError where !error.isCancellation {
            Log.network.error("Discover: trending failed: \(error.errorDescription ?? "unknown", privacy: .public)")
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func search(_ text: String, dismissedMovieIDs: Set<Int>) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await tmdbClient.searchMovies(query: text)
            results = response.results.filter { !dismissedMovieIDs.contains($0.id) }
            errorMessage = nil
            Log.network.debug("Discover: search \"\(text, privacy: .public)\" -> \(response.results.count, privacy: .public) results")
        } catch let error as TMDBError where !error.isCancellation {
            Log.network.error("Discover: search \"\(text, privacy: .public)\" failed: \(error.errorDescription ?? "unknown", privacy: .public)")
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

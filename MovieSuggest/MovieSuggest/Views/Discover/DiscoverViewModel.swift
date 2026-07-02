import Foundation

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
    func queryChanged() {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            errorMessage = nil
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await search(trimmed)
        }
    }

    func loadTrendingIfNeeded() async {
        guard results.isEmpty, query.isEmpty else { return }
        await loadTrending()
    }

    private func loadTrending() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await tmdbClient.trending()
            results = response.results
            errorMessage = nil
        } catch let error as TMDBError where !error.isCancellation {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func search(_ text: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await tmdbClient.searchMovies(query: text)
            results = response.results
            errorMessage = nil
        } catch let error as TMDBError where !error.isCancellation {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

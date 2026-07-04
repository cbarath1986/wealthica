import SwiftUI
import SwiftData

struct WatchNextView: View {
    @Query private var library: [Movie]
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var genreStore: GenreStore
    @StateObject private var viewModel: WatchNextViewModel

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 12)]

    init(tmdbClient: TMDBClient) {
        _viewModel = StateObject(wrappedValue: WatchNextViewModel(tmdbClient: tmdbClient))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView("Couldn't load suggestions", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                        .padding(.top, 60)
                } else if viewModel.isLoading && viewModel.suggestions.isEmpty {
                    ProgressView().padding(.top, 80)
                } else if viewModel.suggestions.isEmpty {
                    ContentUnavailableView(
                        "Nothing to suggest yet",
                        systemImage: "checkmark.circle",
                        description: Text("Mark a few movies as watched and we'll suggest well-rated picks in the same genres.")
                    )
                    .padding(.top, 60)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.suggestions) { scored in
                            NavigationLink(value: scored.movie.id) {
                                MoviePosterCard(movie: scored.movie, caption: caption(for: scored))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Watch Next")
            .navigationDestination(for: Int.self) { movieID in
                MovieDetailView(movieID: movieID)
            }
            .refreshable { await refresh() }
            .task { await refresh() }
        }
    }

    private func caption(for scored: ScoredMovie) -> String? {
        guard let genreID = scored.topGenreID, let name = genreStore.name(for: genreID) else { return nil }
        return "Because you watched \(name.lowercased())"
    }

    private func refresh() async {
        await viewModel.refresh(library: library, preferredLanguages: settingsStore.preferredLanguages)
    }
}

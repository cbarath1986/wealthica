import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @StateObject private var viewModel: DiscoverViewModel

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 12)]

    init(tmdbClient: TMDBClient) {
        _viewModel = StateObject(wrappedValue: DiscoverViewModel(tmdbClient: tmdbClient))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView("Something went wrong", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                        .padding(.top, 60)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.results) { movie in
                            NavigationLink(value: movie.id) {
                                MoviePosterCard(movie: movie, onNotInterested: {
                                    settingsStore.dismiss(movie.id)
                                    viewModel.queryChanged(dismissedMovieIDs: settingsStore.dismissedMovieIDs)
                                })
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
                if viewModel.isLoading {
                    ProgressView().padding()
                }
            }
            .navigationTitle("Discover")
            .searchable(text: $viewModel.query, prompt: "Search movies")
            .onChange(of: viewModel.query) { _, _ in
                viewModel.queryChanged(dismissedMovieIDs: settingsStore.dismissedMovieIDs)
            }
            .navigationDestination(for: Int.self) { movieID in
                MovieDetailView(movieID: movieID)
            }
            .task { await viewModel.loadTrendingIfNeeded(dismissedMovieIDs: settingsStore.dismissedMovieIDs) }
        }
    }
}

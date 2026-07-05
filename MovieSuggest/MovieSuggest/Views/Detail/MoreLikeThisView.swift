import SwiftUI
import SwiftData

/// Full grid version of the small "More like this" rail on a movie's
/// detail screen. Presented as a sheet so it doesn't need its own
/// navigationDestination(for:) wiring in every tab's NavigationStack.
struct MoreLikeThisView: View {
    let sourceMovie: TMDBMovie

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsStore: SettingsStore
    @Query private var library: [Movie]
    @StateObject private var viewModel: MoreLikeThisViewModel

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 12)]

    init(sourceMovie: TMDBMovie, tmdbClient: TMDBClient) {
        self.sourceMovie = sourceMovie
        _viewModel = StateObject(wrappedValue: MoreLikeThisViewModel(tmdbClient: tmdbClient))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView("Couldn't load", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                        .padding(.top, 60)
                } else if viewModel.isLoading && viewModel.results.isEmpty {
                    ProgressView().padding(.top, 80)
                } else if viewModel.results.isEmpty {
                    ContentUnavailableView("No similar movies found", systemImage: "film")
                        .padding(.top, 60)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.results) { scored in
                            NavigationLink(value: scored.movie.id) {
                                MoviePosterCard(movie: scored.movie)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("More Like \(sourceMovie.title)")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Int.self) { movieID in
                MovieDetailView(movieID: movieID)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await viewModel.load(
                    sourceMovie: sourceMovie,
                    libraryIDs: Set(library.map(\.tmdbID)),
                    preferredLanguages: settingsStore.preferredLanguages
                )
            }
        }
    }
}

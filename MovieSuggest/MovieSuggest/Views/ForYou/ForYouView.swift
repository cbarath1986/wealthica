import SwiftUI
import SwiftData

struct ForYouView: View {
    @Query private var library: [Movie]
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var genreStore: GenreStore
    @StateObject private var viewModel: ForYouViewModel

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 12)]

    init(tmdbClient: TMDBClient) {
        _viewModel = StateObject(wrappedValue: ForYouViewModel(tmdbClient: tmdbClient))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.isColdStart {
                    Label("Mark a few movies as watched or favorite to get personalized picks. Here's what's trending for now.",
                          systemImage: "sparkles")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding()
                }

                if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView("Couldn't load recommendations", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                        .padding(.top, 60)
                } else if viewModel.isLoading && viewModel.recommendations.isEmpty {
                    ProgressView().padding(.top, 80)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.recommendations) { scored in
                            NavigationLink(value: scored.movie.id) {
                                MoviePosterCard(movie: scored.movie, caption: caption(for: scored))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("For You")
            .navigationDestination(for: Int.self) { movieID in
                MovieDetailView(movieID: movieID)
            }
            .refreshable { await refresh() }
            .task { await refresh() }
        }
    }

    private func caption(for scored: ScoredMovie) -> String? {
        if let genreID = scored.topGenreID, let name = genreStore.name(for: genreID) {
            return scored.fromSeed ? "Because you liked similar \(name.lowercased())" : "Matches your \(name.lowercased()) taste"
        }
        return scored.fromSeed ? "Similar to your favorites" : nil
    }

    private func refresh() async {
        await viewModel.refresh(
            library: library,
            preferredLanguages: settingsStore.preferredLanguages,
            strictLanguageFilter: settingsStore.strictLanguageFilter,
            preferredGenreIDs: settingsStore.preferredGenreIDs,
            strictGenreFilter: settingsStore.strictGenreFilter
        )
    }
}

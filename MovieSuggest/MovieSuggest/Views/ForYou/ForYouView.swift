import SwiftUI
import SwiftData

struct ForYouView: View {
    @Query private var library: [Movie]
    @Environment(\.tmdbClient) private var tmdbClient
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var genreStore: GenreStore
    @StateObject private var viewModel: ViewModelBox = ViewModelBox()

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.vm?.isColdStart == true {
                    Label("Mark a few movies as watched or favorite to get personalized picks. Here's what's trending for now.",
                          systemImage: "sparkles")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding()
                }

                if let errorMessage = viewModel.vm?.errorMessage {
                    ContentUnavailableView("Couldn't load recommendations", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                        .padding(.top, 60)
                } else if viewModel.vm?.isLoading == true && (viewModel.vm?.recommendations.isEmpty ?? true) {
                    ProgressView().padding(.top, 80)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.vm?.recommendations ?? []) { scored in
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
            .task {
                if viewModel.vm == nil { viewModel.vm = ForYouViewModel(tmdbClient: tmdbClient) }
                await refresh()
            }
        }
    }

    private func caption(for scored: ScoredMovie) -> String? {
        if let genreID = scored.topGenreID, let name = genreStore.name(for: genreID) {
            return scored.fromSeed ? "Because you liked similar \(name.lowercased())" : "Matches your \(name.lowercased()) taste"
        }
        return scored.fromSeed ? "Similar to your favorites" : nil
    }

    private func refresh() async {
        await viewModel.vm?.refresh(
            library: library,
            preferredLanguages: settingsStore.preferredLanguages,
            strictLanguageFilter: settingsStore.strictLanguageFilter
        )
    }
}

private final class ViewModelBox: ObservableObject {
    @Published var vm: ForYouViewModel?
}

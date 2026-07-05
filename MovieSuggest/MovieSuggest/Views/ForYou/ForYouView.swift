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

                if !viewModel.newReleases.isEmpty {
                    newReleasesRail
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
                                MoviePosterCard(movie: scored.movie, caption: caption(for: scored), onNotInterested: {
                                    dismiss(scored.movie.id)
                                })
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                genreFilterBar
            }
            .navigationTitle("For You")
            .navigationDestination(for: Int.self) { movieID in
                MovieDetailView(movieID: movieID)
            }
            .refreshable { await refresh() }
            .task { await refresh() }
        }
    }

    private var newReleasesRail: some View {
        VStack(alignment: .leading) {
            Text("New Releases").font(.headline).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(viewModel.newReleases) { movie in
                        NavigationLink(value: movie.id) {
                            MoviePosterCard(movie: movie, onNotInterested: { dismiss(movie.id) })
                                .frame(width: 120)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }

    private var genreFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                genreChip(title: "All", isSelected: settingsStore.preferredGenreIDs.isEmpty) {
                    guard !settingsStore.preferredGenreIDs.isEmpty else { return }
                    settingsStore.preferredGenreIDs.removeAll()
                    Task { await refresh() }
                }
                ForEach(genreStore.genres) { genre in
                    genreChip(title: genre.name, isSelected: settingsStore.preferredGenreIDs.contains(genre.id)) {
                        toggleGenre(genre.id)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private func genreChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(isSelected ? .white : .primary)
                .background(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func toggleGenre(_ id: Int) {
        if settingsStore.preferredGenreIDs.contains(id) {
            settingsStore.preferredGenreIDs.remove(id)
        } else {
            settingsStore.preferredGenreIDs.insert(id)
        }
        Task { await refresh() }
    }

    private func caption(for scored: ScoredMovie) -> String? {
        if let genreID = scored.topGenreID, let name = genreStore.name(for: genreID) {
            return scored.fromSeed ? "Because you liked similar \(name.lowercased())" : "Matches your \(name.lowercased()) taste"
        }
        return scored.fromSeed ? "Similar to your favorites" : nil
    }

    private func dismiss(_ movieID: Int) {
        settingsStore.dismiss(movieID)
        Task { await refresh() }
    }

    private func refresh() async {
        await viewModel.refresh(
            library: library,
            preferredLanguages: settingsStore.preferredLanguages,
            strictLanguageFilter: settingsStore.strictLanguageFilter,
            preferredGenreIDs: settingsStore.preferredGenreIDs,
            strictGenreFilter: settingsStore.strictGenreFilter,
            dismissedMovieIDs: settingsStore.dismissedMovieIDs
        )
    }
}

import SwiftUI

/// Lets the user review and un-hide movies previously dismissed via
/// "Not Interested". Only tmdbIDs are persisted (SettingsStore.dismissedMovieIDs),
/// so titles are resolved lazily here.
struct HiddenMoviesView: View {
    @Environment(\.tmdbClient) private var tmdbClient
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var moviesByID: [Int: TMDBMovie] = [:]

    private var sortedIDs: [Int] { settingsStore.dismissedMovieIDs.sorted() }

    var body: some View {
        Group {
            if sortedIDs.isEmpty {
                ContentUnavailableView(
                    "No hidden movies",
                    systemImage: "hand.thumbsdown",
                    description: Text("Movies you mark \"Not Interested\" show up here so you can bring them back.")
                )
            } else {
                List {
                    ForEach(sortedIDs, id: \.self) { movieID in
                        HStack {
                            Text(moviesByID[movieID]?.title ?? "Movie #\(movieID)")
                            Spacer()
                            Button("Unhide") { settingsStore.undismiss(movieID) }
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
        .navigationTitle("Hidden Movies")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadTitles() }
    }

    private func loadTitles() async {
        let idsNeedingTitles = sortedIDs.filter { moviesByID[$0] == nil }
        guard !idsNeedingTitles.isEmpty else { return }
        await withTaskGroup(of: (Int, TMDBMovie?).self) { group in
            for movieID in idsNeedingTitles {
                group.addTask { [tmdbClient] in
                    let details = try? await tmdbClient.movieDetails(id: movieID)
                    return (movieID, details?.asMovie)
                }
            }
            for await (movieID, movie) in group {
                if let movie {
                    moviesByID[movieID] = movie
                }
            }
        }
    }
}

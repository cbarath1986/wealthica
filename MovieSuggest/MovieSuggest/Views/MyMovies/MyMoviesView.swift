import SwiftUI
import SwiftData

struct MyMoviesView: View {
    private enum Segment: String, CaseIterable {
        case watched = "Watched"
        case favorites = "Favorites"
        case watchlist = "Watchlist"
    }

    @Query(sort: \Movie.addedAt, order: .reverse) private var allMovies: [Movie]
    @Environment(\.modelContext) private var modelContext
    @State private var segment: Segment = .watched

    private var filtered: [Movie] {
        switch segment {
        case .watched: return allMovies.filter(\.isWatched)
        case .favorites: return allMovies.filter(\.isFavorite)
        case .watchlist: return allMovies.filter(\.isWatchlisted)
        }
    }

    private var emptyStateTitle: String {
        switch segment {
        case .watched: return "No watched movies yet"
        case .favorites: return "No favorites yet"
        case .watchlist: return "Nothing saved for later yet"
        }
    }

    private var emptyStateIcon: String {
        switch segment {
        case .watched: return "eye"
        case .favorites: return "heart"
        case .watchlist: return "bookmark"
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filtered.isEmpty {
                    ContentUnavailableView(
                        emptyStateTitle,
                        systemImage: emptyStateIcon,
                        description: Text("Movies you mark from a detail screen show up here.")
                    )
                } else {
                    List {
                        ForEach(filtered) { movie in
                            NavigationLink(value: movie.tmdbID) {
                                MovieRow(
                                    movie: movie.asDTO,
                                    isWatched: movie.isWatched,
                                    isFavorite: movie.isFavorite,
                                    isWatchlisted: movie.isWatchlisted
                                )
                            }
                        }
                        .onDelete(perform: remove)
                    }
                }
            }
            .navigationTitle("My Movies")
            .toolbar {
                Picker("Segment", selection: $segment) {
                    ForEach(Segment.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .navigationDestination(for: Int.self) { movieID in
                MovieDetailView(movieID: movieID, initialMovie: filtered.first(where: { $0.tmdbID == movieID })?.asDTO)
            }
        }
    }

    private func remove(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filtered[index])
        }
    }
}

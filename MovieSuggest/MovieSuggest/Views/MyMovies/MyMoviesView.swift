import SwiftUI
import SwiftData

struct MyMoviesView: View {
    private enum Segment: String, CaseIterable {
        case watched = "Watched"
        case favorites = "Favorites"
    }

    @Query(sort: \Movie.addedAt, order: .reverse) private var allMovies: [Movie]
    @Environment(\.modelContext) private var modelContext
    @State private var segment: Segment = .watched

    private var filtered: [Movie] {
        allMovies.filter { segment == .watched ? $0.isWatched : $0.isFavorite }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filtered.isEmpty {
                    ContentUnavailableView(
                        segment == .watched ? "No watched movies yet" : "No favorites yet",
                        systemImage: segment == .watched ? "eye" : "heart",
                        description: Text("Movies you mark from a detail screen show up here.")
                    )
                } else {
                    List {
                        ForEach(filtered) { movie in
                            NavigationLink(value: movie.tmdbID) {
                                MovieRow(movie: movie.asDTO, isWatched: movie.isWatched, isFavorite: movie.isFavorite)
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

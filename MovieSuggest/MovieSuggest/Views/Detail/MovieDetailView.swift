import SwiftUI
import SwiftData

struct MovieDetailView: View {
    let movieID: Int
    /// Used to render immediately while full details load.
    var initialMovie: TMDBMovie?

    @Environment(\.tmdbClient) private var tmdbClient
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var genreStore: GenreStore

    @State private var details: TMDBMovieDetails?
    @State private var similar: [TMDBMovie] = []
    @State private var loadError: String?

    @Query private var libraryMatches: [Movie]

    init(movieID: Int, initialMovie: TMDBMovie? = nil) {
        self.movieID = movieID
        self.initialMovie = initialMovie
        _libraryMatches = Query(filter: #Predicate<Movie> { $0.tmdbID == movieID })
    }

    private var libraryRecord: Movie? { libraryMatches.first }
    private var displayMovie: TMDBMovie? { details?.asMovie ?? initialMovie }

    var body: some View {
        ScrollView {
            if let displayMovie {
                VStack(alignment: .leading, spacing: 16) {
                    AsyncImage(url: TMDBImage.backdrop(displayMovie.backdropPath ?? details?.backdropPath)) { phase in
                        if case .success(let image) = phase {
                            image.resizable().aspectRatio(16 / 9, contentMode: .fill)
                        } else {
                            Rectangle().fill(.quaternary).aspectRatio(16 / 9, contentMode: .fill)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(displayMovie.title).font(.title2.bold())

                        HStack(spacing: 8) {
                            if let year = displayMovie.releaseYear { Text(year) }
                            if let runtime = details?.runtime, runtime > 0 {
                                Text("· \(runtime) min")
                            }
                            if let voteAverage = displayMovie.voteAverage, voteAverage > 0 {
                                Text("· ⭐️ \(String(format: "%.1f", voteAverage))")
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                        if let genreIDs = displayMovie.genreIds, !genreIDs.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(genreIDs, id: \.self) { id in
                                        if let name = genreStore.name(for: id) {
                                            Text(name)
                                                .font(.caption)
                                                .padding(.horizontal, 10).padding(.vertical, 4)
                                                .background(.quaternary, in: Capsule())
                                        }
                                    }
                                }
                            }
                        }

                        actionButtons(for: displayMovie)

                        if let overview = displayMovie.overview, !overview.isEmpty {
                            Text(overview).font(.body)
                        }
                    }
                    .padding(.horizontal)

                    if !similar.isEmpty {
                        VStack(alignment: .leading) {
                            Text("More like this").font(.headline).padding(.horizontal)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(alignment: .top, spacing: 12) {
                                    ForEach(similar) { movie in
                                        NavigationLink(value: movie.id) {
                                            MoviePosterCard(movie: movie).frame(width: 120)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            } else if let loadError {
                ContentUnavailableView("Couldn't load movie", systemImage: "exclamationmark.triangle", description: Text(loadError))
            } else {
                ProgressView().padding(.top, 80)
            }
        }
        .navigationTitle(displayMovie?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private func actionButtons(for movie: TMDBMovie) -> some View {
        HStack(spacing: 12) {
            Button {
                modelContext.updateLibrary(for: movie) { $0.toggleWatched() }
            } label: {
                Label(libraryRecord?.isWatched == true ? "Watched" : "Mark Watched",
                      systemImage: libraryRecord?.isWatched == true ? "eye.fill" : "eye")
            }
            .buttonStyle(.bordered)
            .tint(libraryRecord?.isWatched == true ? .accentColor : .secondary)

            Button {
                modelContext.updateLibrary(for: movie) { $0.toggleFavorite() }
            } label: {
                Label(libraryRecord?.isFavorite == true ? "Favorited" : "Favorite",
                      systemImage: libraryRecord?.isFavorite == true ? "heart.fill" : "heart")
            }
            .buttonStyle(.bordered)
            .tint(libraryRecord?.isFavorite == true ? .red : .secondary)
        }
    }

    private func load() async {
        do {
            async let detailsTask = tmdbClient.movieDetails(id: movieID)
            async let recommendationsTask = try? tmdbClient.recommendations(for: movieID)
            details = try await detailsTask
            if let recommended = await recommendationsTask, !recommended.results.isEmpty {
                similar = recommended.results
            } else if let fallback = try? await tmdbClient.similar(to: movieID) {
                similar = fallback.results
            }
        } catch let error as TMDBError {
            loadError = error.errorDescription
        } catch {
            loadError = error.localizedDescription
        }
    }
}

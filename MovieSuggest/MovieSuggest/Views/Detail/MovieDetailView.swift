import SwiftUI
import SwiftData

/// Identifies which person's filmography to show in the person sheet.
private struct PersonRoute: Identifiable {
    let id: Int
    let name: String
}

struct MovieDetailView: View {
    let movieID: Int
    /// Used to render immediately while full details load.
    var initialMovie: TMDBMovie?

    @Environment(\.tmdbClient) private var tmdbClient
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var genreStore: GenreStore

    @State private var details: TMDBMovieDetails?
    @State private var similar: [TMDBMovie] = []
    @State private var credits: TMDBCredits?
    @State private var watchProviderRegion: TMDBWatchProviderRegion?
    @State private var loadError: String?
    @State private var showingMoreLikeThis = false
    @State private var selectedPerson: PersonRoute?

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

                    if let watchProviderRegion {
                        watchProvidersSection(watchProviderRegion)
                    }

                    if let credits, !credits.cast.isEmpty {
                        castAndCrewSection(credits)
                    }

                    if !similar.isEmpty {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("More like this").font(.headline)
                                Spacer()
                                Button("See All") { showingMoreLikeThis = true }
                                    .font(.subheadline)
                            }
                            .padding(.horizontal)
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
        .sheet(isPresented: $showingMoreLikeThis) {
            if let displayMovie {
                MoreLikeThisView(sourceMovie: displayMovie, tmdbClient: tmdbClient)
            }
        }
        .sheet(item: $selectedPerson) { person in
            PersonFilmographyView(personID: person.id, personName: person.name, tmdbClient: tmdbClient)
        }
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

            Spacer()

            Button {
                modelContext.updateLibrary(for: movie) { $0.toggleWatchlisted() }
            } label: {
                Image(systemName: libraryRecord?.isWatchlisted == true ? "bookmark.fill" : "bookmark")
            }
            .buttonStyle(.bordered)
            .tint(libraryRecord?.isWatchlisted == true ? .accentColor : .secondary)
        }
    }

    @ViewBuilder
    private func watchProvidersSection(_ region: TMDBWatchProviderRegion) -> some View {
        let providers = dedupedProviders(in: region)
        if !providers.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Where to Watch").font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(providers) { provider in
                            VStack(spacing: 4) {
                                AsyncImage(url: TMDBImage.provider(provider.logoPath)) { phase in
                                    if case .success(let image) = phase {
                                        image.resizable()
                                    } else {
                                        Rectangle().fill(.quaternary)
                                    }
                                }
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                Text(provider.providerName)
                                    .font(.caption2)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 64)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    /// flatrate (subscription) first since that's the most actionable —
    /// "I can watch this right now with something I already pay for" —
    /// then rent, then buy, deduplicated since the same service sometimes
    /// appears in more than one list.
    private func dedupedProviders(in region: TMDBWatchProviderRegion) -> [TMDBWatchProvider] {
        var seenIDs = Set<Int>()
        var result: [TMDBWatchProvider] = []
        for provider in (region.flatrate ?? []) + (region.rent ?? []) + (region.buy ?? []) {
            if seenIDs.insert(provider.id).inserted {
                result.append(provider)
            }
        }
        return result
    }

    @ViewBuilder
    private func castAndCrewSection(_ credits: TMDBCredits) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let director = credits.crew.first(where: { $0.job == "Director" }) {
                Button {
                    selectedPerson = PersonRoute(id: director.id, name: director.name)
                } label: {
                    Text("Directed by \(director.name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .underline()
                }
                .buttonStyle(.plain)
            }

            Text("Cast").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(credits.cast.prefix(15)) { member in
                        Button {
                            selectedPerson = PersonRoute(id: member.id, name: member.name)
                        } label: {
                            VStack(spacing: 4) {
                                AsyncImage(url: TMDBImage.profile(member.profilePath)) { phase in
                                    if case .success(let image) = phase {
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } else {
                                        ZStack {
                                            Rectangle().fill(.quaternary)
                                            Image(systemName: "person.fill").foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .frame(width: 70, height: 70)
                                .clipShape(Circle())

                                Text(member.name)
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .frame(width: 80)

                                if let character = member.character, !character.isEmpty {
                                    Text(character)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .frame(width: 80)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func load() async {
        do {
            async let detailsTask = tmdbClient.movieDetails(id: movieID)
            async let recommendationsTask: TMDBPagedResponse<TMDBMovie>? = try? tmdbClient.recommendations(for: movieID)
            async let creditsTask: TMDBCredits? = try? tmdbClient.credits(for: movieID)
            async let providersTask: TMDBWatchProvidersResponse? = try? tmdbClient.watchProviders(for: movieID)

            details = try await detailsTask

            if let recommended = await recommendationsTask, !recommended.results.isEmpty {
                similar = recommended.results
            } else if let fallback = try? await tmdbClient.similar(to: movieID) {
                similar = fallback.results
            }

            credits = await creditsTask

            if let providersResponse = await providersTask {
                let regionCode = Locale.current.region?.identifier ?? "US"
                watchProviderRegion = providersResponse.results[regionCode]
            }
        } catch let error as TMDBError {
            loadError = error.errorDescription
        } catch {
            loadError = error.localizedDescription
        }
    }
}

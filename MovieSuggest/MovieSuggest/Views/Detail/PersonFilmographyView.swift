import SwiftUI

/// Shows a person's (actor or director) filmography, reached by tapping
/// them in a movie's Cast & Crew section. Presented as a sheet with its
/// own NavigationStack, same pattern as MoreLikeThisView.
struct PersonFilmographyView: View {
    let personID: Int
    let personName: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PersonFilmographyViewModel

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 12)]

    init(personID: Int, personName: String, tmdbClient: TMDBClient) {
        self.personID = personID
        self.personName = personName
        _viewModel = StateObject(wrappedValue: PersonFilmographyViewModel(tmdbClient: tmdbClient))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView("Couldn't load", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                        .padding(.top, 60)
                } else if viewModel.isLoading && viewModel.movies.isEmpty {
                    ProgressView().padding(.top, 80)
                } else if viewModel.movies.isEmpty {
                    ContentUnavailableView("No movies found", systemImage: "film")
                        .padding(.top, 60)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.movies) { movie in
                            NavigationLink(value: movie.id) {
                                MoviePosterCard(movie: movie)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(personName)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Int.self) { movieID in
                MovieDetailView(movieID: movieID)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await viewModel.load(personID: personID) }
        }
    }
}

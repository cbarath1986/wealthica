import Foundation
import Combine

@MainActor
final class PersonFilmographyViewModel: ObservableObject {
    @Published private(set) var movies: [TMDBMovie] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let tmdbClient: TMDBClient

    init(tmdbClient: TMDBClient) {
        self.tmdbClient = tmdbClient
    }

    func load(personID: Int) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let credits = try await tmdbClient.personMovieCredits(personID: personID)
            var moviesByID: [Int: TMDBMovie] = [:]
            for movie in credits.cast + credits.crew {
                moviesByID[movie.id] = movie
            }
            // Most notable work first, for actors/directors with large
            // back catalogs; deterministic tie-break for equal popularity.
            movies = moviesByID.values.sorted { lhs, rhs in
                let lhsPopularity = lhs.popularity ?? 0
                let rhsPopularity = rhs.popularity ?? 0
                if lhsPopularity != rhsPopularity { return lhsPopularity > rhsPopularity }
                return lhs.id < rhs.id
            }
            Log.recommendation.info("Person filmography (\(personID, privacy: .public)): \(self.movies.count, privacy: .public) movies")
        } catch let error as TMDBError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

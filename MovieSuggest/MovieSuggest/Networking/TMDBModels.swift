import Foundation

/// Paged list envelope returned by TMDB list endpoints
/// (search, trending, discover, recommendations, similar).
struct TMDBPagedResponse<Result: Decodable>: Decodable {
    let page: Int
    let results: [Result]
    let totalPages: Int
    let totalResults: Int
}

/// A movie as it appears in TMDB list responses. Field names map from
/// snake_case via the shared decoder (see `TMDBClient.makeDecoder()`).
struct TMDBMovie: Decodable, Identifiable, Hashable {
    let id: Int
    let title: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let genreIds: [Int]?
    let originalLanguage: String?
    let voteAverage: Double?
    let voteCount: Int?
    let popularity: Double?

    /// TMDB sends release_date as "yyyy-MM-dd", occasionally empty.
    var releaseYear: String? {
        guard let releaseDate, releaseDate.count >= 4 else { return nil }
        return String(releaseDate.prefix(4))
    }
}

/// Full movie record from `/movie/{id}` — genres come expanded here,
/// not as bare ids.
struct TMDBMovieDetails: Decodable {
    let id: Int
    let title: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let genres: [TMDBGenre]
    let originalLanguage: String?
    let voteAverage: Double?
    let voteCount: Int?
    let popularity: Double?
    let runtime: Int?
    let tagline: String?

    /// List-shaped view of the details, used when upserting into the library
    /// so the record carries the full genre list.
    var asMovie: TMDBMovie {
        TMDBMovie(
            id: id,
            title: title,
            overview: overview,
            posterPath: posterPath,
            backdropPath: backdropPath,
            releaseDate: releaseDate,
            genreIds: genres.map(\.id),
            originalLanguage: originalLanguage,
            voteAverage: voteAverage,
            voteCount: voteCount,
            popularity: popularity
        )
    }
}

struct TMDBGenre: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
}

struct TMDBGenreListResponse: Decodable {
    let genres: [TMDBGenre]
}

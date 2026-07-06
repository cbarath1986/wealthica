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

// MARK: - Credits

struct TMDBCredits: Decodable {
    let cast: [TMDBCastMember]
    let crew: [TMDBCrewMember]
}

struct TMDBCastMember: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?
}

struct TMDBCrewMember: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let job: String?
    let department: String?
    let profilePath: String?
}

/// A person's filmography from `/person/{id}/movie_credits`. Each cast/crew
/// entry there is shaped like a regular movie (plus role fields we don't
/// need), so it decodes directly as `TMDBMovie` — Codable simply ignores
/// the extra `character`/`job`/`credit_id` keys.
struct TMDBPersonMovieCredits: Decodable {
    let cast: [TMDBMovie]
    let crew: [TMDBMovie]
}

// MARK: - Watch providers

struct TMDBWatchProvidersResponse: Decodable {
    let results: [String: TMDBWatchProviderRegion]
}

struct TMDBWatchProviderRegion: Decodable {
    let link: String?
    let flatrate: [TMDBWatchProvider]?
    let rent: [TMDBWatchProvider]?
    let buy: [TMDBWatchProvider]?
}

struct TMDBWatchProvider: Decodable, Identifiable, Hashable {
    let providerId: Int
    let providerName: String
    let logoPath: String?

    var id: Int { providerId }
}

// MARK: - Keywords

/// TMDB keyword ids aren't documented/stable, so mood search resolves
/// human-readable names to ids at runtime via `/search/keyword` rather than
/// hardcoding them (see `MoodKeywordResolver`).
struct TMDBKeywordSearchResponse: Decodable {
    let results: [TMDBKeyword]
}

struct TMDBKeyword: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
}

// MARK: - Videos

struct TMDBVideosResponse: Decodable {
    let results: [TMDBVideo]

    /// Prefers an official trailer, falling back to any trailer, then nil
    /// if there isn't one on YouTube at all.
    var bestYouTubeTrailer: TMDBVideo? {
        let trailers = results.filter { $0.site == "YouTube" && $0.type == "Trailer" }
        return trailers.first(where: \.official) ?? trailers.first
    }
}

struct TMDBVideo: Decodable, Identifiable, Hashable {
    let id: String
    let key: String
    let name: String
    let site: String
    let type: String
    let official: Bool

    var youTubeURL: URL? {
        guard site == "YouTube" else { return nil }
        return URL(string: "https://www.youtube.com/watch?v=\(key)")
    }
}

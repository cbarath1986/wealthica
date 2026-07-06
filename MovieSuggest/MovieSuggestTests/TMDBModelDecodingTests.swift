import XCTest
@testable import MovieSuggest

final class TMDBModelDecodingTests: XCTestCase {
    private let decoder = TMDBClient.makeDecoder()

    func testDecodesSearchResponse() throws {
        let json = """
        {
          "page": 1,
          "results": [
            {
              "id": 27205,
              "title": "Inception",
              "overview": "A thief who steals secrets.",
              "poster_path": "/poster.jpg",
              "backdrop_path": "/backdrop.jpg",
              "release_date": "2010-07-15",
              "genre_ids": [28, 878],
              "original_language": "en",
              "vote_average": 8.4,
              "vote_count": 34000,
              "popularity": 123.4
            }
          ],
          "total_pages": 10,
          "total_results": 200
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(TMDBPagedResponse<TMDBMovie>.self, from: json)
        XCTAssertEqual(response.results.first?.title, "Inception")
        XCTAssertEqual(response.results.first?.releaseYear, "2010")
        XCTAssertEqual(response.totalPages, 10)
    }

    func testTolerantOfNullPosterAndEmptyReleaseDate() throws {
        let json = """
        {
          "id": 1,
          "title": "Unreleased",
          "overview": null,
          "poster_path": null,
          "backdrop_path": null,
          "release_date": "",
          "genre_ids": [],
          "original_language": "en",
          "vote_average": 0,
          "vote_count": 0,
          "popularity": 0
        }
        """.data(using: .utf8)!

        let movie = try decoder.decode(TMDBMovie.self, from: json)
        XCTAssertNil(movie.posterPath)
        XCTAssertNil(movie.releaseYear)
    }

    func testDecodesMovieDetailsWithExpandedGenres() throws {
        let json = """
        {
          "id": 27205,
          "title": "Inception",
          "overview": "A thief who steals secrets.",
          "poster_path": "/poster.jpg",
          "backdrop_path": "/backdrop.jpg",
          "release_date": "2010-07-15",
          "genres": [{"id": 28, "name": "Action"}, {"id": 878, "name": "Science Fiction"}],
          "original_language": "en",
          "vote_average": 8.4,
          "vote_count": 34000,
          "popularity": 123.4,
          "runtime": 148,
          "tagline": "Your mind is the scene of the crime."
        }
        """.data(using: .utf8)!

        let details = try decoder.decode(TMDBMovieDetails.self, from: json)
        XCTAssertEqual(details.genres.map(\.name), ["Action", "Science Fiction"])
        XCTAssertEqual(details.asMovie.genreIds, [28, 878])
        XCTAssertEqual(details.runtime, 148)
    }

    func testDecodesGenreList() throws {
        let json = """
        { "genres": [{"id": 28, "name": "Action"}, {"id": 12, "name": "Adventure"}] }
        """.data(using: .utf8)!

        let response = try decoder.decode(TMDBGenreListResponse.self, from: json)
        XCTAssertEqual(response.genres.count, 2)
    }

    func testDecodesKeywordSearchResponse() throws {
        let json = """
        { "results": [{"id": 9748, "name": "feel-good"}, {"id": 156021, "name": "uplifting"}] }
        """.data(using: .utf8)!

        let response = try decoder.decode(TMDBKeywordSearchResponse.self, from: json)
        XCTAssertEqual(response.results.map(\.name), ["feel-good", "uplifting"])
        XCTAssertEqual(response.results.first?.id, 9748)
    }
}

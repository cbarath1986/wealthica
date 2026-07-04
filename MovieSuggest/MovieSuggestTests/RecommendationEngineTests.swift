import XCTest
@testable import MovieSuggest

final class RecommendationEngineTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func movie(id: Int, genreIds: [Int], language: String = "en", vote: Double = 7.0, popularity: Double = 10) -> TMDBMovie {
        TMDBMovie(
            id: id, title: "Movie \(id)", overview: nil, posterPath: nil, backdropPath: nil,
            releaseDate: nil, genreIds: genreIds, originalLanguage: language,
            voteAverage: vote, voteCount: 100, popularity: popularity
        )
    }

    func testFavoritesOutweighWatchedInGenreAffinity() {
        let library = [
            LibraryItem(tmdbID: 1, genreIDs: [28], isFavorite: true, referenceDate: now),
            LibraryItem(tmdbID: 2, genreIDs: [18], isFavorite: false, referenceDate: now),
        ]
        let affinity = RecommendationEngine.genreAffinity(library: library, now: now)
        XCTAssertEqual(affinity[28], 1.0)
        XCTAssertEqual(affinity[18]!, 1.0 / 3.0, accuracy: 0.0001)
    }

    func testWatchedMoviesAreExcludedFromResults() {
        let library = [LibraryItem(tmdbID: 42, genreIDs: [28], isFavorite: true, referenceDate: now)]
        let candidates = [
            Candidate(movie: movie(id: 42, genreIds: [28]), seedHits: 0),
            Candidate(movie: movie(id: 99, genreIds: [28]), seedHits: 0),
        ]
        let results = RecommendationEngine.score(candidates: candidates, library: library, preferredLanguages: ["en"], now: now)
        XCTAssertFalse(results.contains { $0.movie.id == 42 })
        XCTAssertTrue(results.contains { $0.movie.id == 99 })
    }

    func testLanguageBoostsMatchingCandidatesHigher() {
        let library = [LibraryItem(tmdbID: 1, genreIDs: [28], isFavorite: true, referenceDate: now)]
        let candidates = [
            Candidate(movie: movie(id: 10, genreIds: [28], language: "en", vote: 7, popularity: 10), seedHits: 0),
            Candidate(movie: movie(id: 11, genreIds: [28], language: "fr", vote: 7, popularity: 10), seedHits: 0),
        ]
        let results = RecommendationEngine.score(candidates: candidates, library: library, preferredLanguages: ["en"], now: now)
        XCTAssertEqual(results.first?.movie.id, 10)
    }

    func testStrictLanguageFilterExcludesNonMatching() {
        let library = [LibraryItem(tmdbID: 1, genreIDs: [28], isFavorite: true, referenceDate: now)]
        let candidates = [
            Candidate(movie: movie(id: 10, genreIds: [28], language: "en"), seedHits: 0),
            Candidate(movie: movie(id: 11, genreIds: [28], language: "fr"), seedHits: 0),
        ]
        let results = RecommendationEngine.score(
            candidates: candidates, library: library, preferredLanguages: ["en"],
            strictLanguageFilter: true, now: now
        )
        XCTAssertEqual(results.map(\.movie.id), [10])
    }

    func testRecencyDecayLowersOlderFavoriteInfluence() {
        let recent = LibraryItem(tmdbID: 1, genreIDs: [28], isFavorite: true, referenceDate: now)
        let old = LibraryItem(tmdbID: 2, genreIDs: [12], isFavorite: true, referenceDate: now.addingTimeInterval(-400 * 86400))
        let affinity = RecommendationEngine.genreAffinity(library: [recent, old], now: now)
        XCTAssertGreaterThan(affinity[28]!, affinity[12]!)
    }

    func testEmptyLibraryProducesZeroAffinityAndNoExclusions() {
        let candidates = [Candidate(movie: movie(id: 1, genreIds: [28]), seedHits: 0)]
        let results = RecommendationEngine.score(candidates: candidates, library: [], preferredLanguages: ["en"], now: now)
        XCTAssertEqual(results.count, 1)
    }

    func testDeterministicTieBreakByPopularityThenID() {
        let candidates = [
            Candidate(movie: movie(id: 20, genreIds: [], language: "de", popularity: 5), seedHits: 0),
            Candidate(movie: movie(id: 10, genreIds: [], language: "de", popularity: 5), seedHits: 0),
            Candidate(movie: movie(id: 5, genreIds: [], language: "de", popularity: 9), seedHits: 0),
        ]
        let results = RecommendationEngine.score(candidates: candidates, library: [], preferredLanguages: ["en"], now: now)
        XCTAssertEqual(results.map(\.movie.id), [5, 10, 20])
    }

    func testSeedHitsIncreaseScore() {
        let noSeed = Candidate(movie: movie(id: 1, genreIds: [], language: "de", popularity: 1), seedHits: 0)
        let withSeed = Candidate(movie: movie(id: 2, genreIds: [], language: "de", popularity: 1), seedHits: 2)
        let results = RecommendationEngine.score(candidates: [noSeed, withSeed], library: [], preferredLanguages: ["en"], now: now)
        XCTAssertEqual(results.first?.movie.id, 2)
    }

    func testPreferredGenreBoostsMatchingCandidatesHigher() {
        let candidates = [
            Candidate(movie: movie(id: 10, genreIds: [28], language: "de", popularity: 10), seedHits: 0),
            Candidate(movie: movie(id: 11, genreIds: [35], language: "de", popularity: 10), seedHits: 0),
        ]
        let results = RecommendationEngine.score(
            candidates: candidates, library: [], preferredLanguages: ["en"],
            preferredGenreIDs: [35], now: now
        )
        XCTAssertEqual(results.first?.movie.id, 11)
    }

    func testStrictGenreFilterExcludesNonMatching() {
        let candidates = [
            Candidate(movie: movie(id: 10, genreIds: [28], language: "en"), seedHits: 0),
            Candidate(movie: movie(id: 11, genreIds: [35], language: "en"), seedHits: 0),
        ]
        let results = RecommendationEngine.score(
            candidates: candidates, library: [], preferredLanguages: ["en"],
            preferredGenreIDs: [35], strictGenreFilter: true, now: now
        )
        XCTAssertEqual(results.map(\.movie.id), [11])
    }

    func testEmptyPreferredGenreIDsPreservesOriginalWeighting() {
        let library = [LibraryItem(tmdbID: 1, genreIDs: [28], isFavorite: true, referenceDate: now)]
        let candidates = [Candidate(movie: movie(id: 10, genreIds: [28], language: "en"), seedHits: 0)]
        let results = RecommendationEngine.score(candidates: candidates, library: library, preferredLanguages: ["en"], now: now)
        // genreScore=1.0, seedScore=0, languageScore=1.0, qualityScore=0.7
        // total = 0.45*1.0 + 0.25*0 + 0.20*1.0 + 0.10*0.7 = 0.72
        XCTAssertEqual(results.first?.total ?? 0, 0.72, accuracy: 0.0001)
    }
}

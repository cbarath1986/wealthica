import XCTest
@testable import MovieSuggest

final class MoodTagTests: XCTestCase {
    func testAllMoodsHaveUniqueIDs() {
        let ids = MoodTag.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "MoodTag ids must be unique for stable Identifiable/selection behavior")
    }

    func testAllMoodsHaveTitleIconAndKeywords() {
        for mood in MoodTag.all {
            XCTAssertFalse(mood.title.isEmpty)
            XCTAssertFalse(mood.icon.isEmpty)
            XCTAssertFalse(mood.keywordNames.isEmpty, "\(mood.id) has no keyword names to resolve")
        }
    }
}

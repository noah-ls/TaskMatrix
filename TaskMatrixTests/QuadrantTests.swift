import XCTest

final class QuadrantTests: XCTestCase {
    func testAllCasesCount() {
        XCTAssertEqual(Quadrant.allCases.count, 4)
    }

    func testRawValueRoundTrip() {
        for quadrant in Quadrant.allCases {
            XCTAssertEqual(Quadrant(rawValue: quadrant.rawValue), quadrant)
        }
    }

    func testStrategiesAreDistinctAndNonEmpty() {
        let strategies = Quadrant.allCases.map(\.strategy)
        XCTAssertEqual(Set(strategies).count, 4)
        XCTAssertFalse(strategies.contains { $0.isEmpty })
    }

    func testKnownStrategies() {
        XCTAssertEqual(Quadrant.q1.strategy, "Do First")
        XCTAssertEqual(Quadrant.q2.strategy, "Schedule")
        XCTAssertEqual(Quadrant.q3.strategy, "Delegate")
        XCTAssertEqual(Quadrant.q4.strategy, "Eliminate")
    }

    func testTitlesAndSubtitlesNonEmpty() {
        for quadrant in Quadrant.allCases {
            XCTAssertFalse(quadrant.title.isEmpty)
            XCTAssertFalse(quadrant.subtitle.isEmpty)
        }
    }
}

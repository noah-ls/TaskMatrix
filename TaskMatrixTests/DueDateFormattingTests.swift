import XCTest

final class DueDateFormattingTests: XCTestCase {
    private let calendar = Calendar.current

    private func day(offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date()))!
    }

    func testToday() {
        XCTAssertEqual(DueDateFormatting.shortLabel(for: day(offset: 0)), "Today")
    }

    func testTomorrow() {
        XCTAssertEqual(DueDateFormatting.shortLabel(for: day(offset: 1)), "Tomorrow")
    }

    func testYesterday() {
        XCTAssertEqual(DueDateFormatting.shortLabel(for: day(offset: -1)), "Yesterday")
    }

    func testDistantDateIsAbsoluteAndNonEmpty() {
        let label = DueDateFormatting.shortLabel(for: day(offset: 30))
        XCTAssertFalse(["Today", "Tomorrow", "Yesterday"].contains(label))
        XCTAssertFalse(label.isEmpty)
    }
}

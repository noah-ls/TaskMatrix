import XCTest

final class StatsCalculatorTests: XCTestCase {
    private let calendar = Calendar.current

    private var today: Date { calendar.startOfDay(for: Date()) }

    private func at(_ dayOffset: Int, hour: Int = 12) -> Date {
        let day = calendar.date(byAdding: .day, value: dayOffset, to: today)!
        return calendar.date(byAdding: .hour, value: hour, to: day)!
    }

    private func task(
        _ id: String,
        _ quadrant: Quadrant,
        completed: Bool = false,
        due: Date? = nil,
        completedAt: Date? = nil
    ) -> TaskItem {
        TaskItem(
            id: id,
            title: id,
            quadrant: quadrant,
            isCompleted: completed,
            createdAt: at(-1),
            dueDate: due,
            completedAt: completedAt
        )
    }

    func testOpenAndCompletedCounts() {
        let tasks = [
            task("a", .q1),
            task("b", .q2),
            task("c", .q1, completed: true, completedAt: at(0))
        ]
        let summary = StatsCalculator.summarize(tasks)
        XCTAssertEqual(summary.openCount, 2)
        XCTAssertEqual(summary.completedCount, 1)
    }

    func testOverdueCountsOnlyOpenPastDue() {
        let tasks = [
            task("overdue", .q1, due: at(-2)),
            task("future", .q1, due: at(3)),
            task("doneLate", .q1, completed: true, due: at(-5), completedAt: at(0))
        ]
        let summary = StatsCalculator.summarize(tasks)
        XCTAssertEqual(summary.overdueCount, 1)
    }

    func testOnTimeRate() {
        let tasks = [
            task("onTime", .q1, completed: true, due: at(2), completedAt: at(0)),
            task("late", .q1, completed: true, due: at(-2), completedAt: at(0))
        ]
        let summary = StatsCalculator.summarize(tasks)
        XCTAssertEqual(summary.onTimeRate, 0.5)
    }

    func testOnTimeRateNilWhenNoCompletedWithDueDate() {
        let summary = StatsCalculator.summarize([task("a", .q1)])
        XCTAssertNil(summary.onTimeRate)
    }

    func testQuadrantSlices() {
        let tasks = [task("a", .q1), task("b", .q1), task("c", .q2)]
        let summary = StatsCalculator.summarize(tasks)

        XCTAssertEqual(summary.quadrantSlices.count, 4)
        let q1 = summary.quadrantSlices.first { $0.quadrant == .q1 }
        let q2 = summary.quadrantSlices.first { $0.quadrant == .q2 }
        XCTAssertEqual(q1?.openCount, 2)
        XCTAssertEqual(q2?.openCount, 1)
    }

    func testDailyCompletionsHasFourteenEntriesAndCountsToday() {
        let now = at(0, hour: 23)
        let tasks = [
            task("x", .q1, completed: true, completedAt: at(0, hour: 10)),
            task("y", .q1, completed: true, completedAt: at(0, hour: 11)),
            task("z", .q1, completed: true, completedAt: at(-3, hour: 9))
        ]
        let summary = StatsCalculator.summarize(tasks, now: now)
        XCTAssertEqual(summary.dailyCompletions.count, 14)
        XCTAssertEqual(summary.dailyCompletions.last?.count, 2)
    }

    func testInsightAllClearWhenNoOpenTasks() {
        let summary = StatsCalculator.summarize([])
        XCTAssertTrue(summary.insight.contains("All clear"))
    }

    func testInsightFirefightingWhenQ1Majority() {
        let tasks = [task("a", .q1), task("b", .q1), task("c", .q2)]
        let summary = StatsCalculator.summarize(tasks)
        XCTAssertTrue(summary.insight.lowercased().contains("firefighting"))
    }

    func testInsightOverdueWhenManyOverdue() {
        let tasks = [
            task("a", .q1, due: at(-2)),
            task("b", .q2, due: at(-3)),
            task("c", .q2)
        ]
        let summary = StatsCalculator.summarize(tasks)
        XCTAssertTrue(summary.insight.lowercased().contains("overdue"))
    }
}

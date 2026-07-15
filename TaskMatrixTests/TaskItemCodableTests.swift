import XCTest

final class TaskItemCodableTests: XCTestCase {
    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    /// A save written before subtasks / due dates / completedAt / order
    /// existed must still decode, defaulting the new fields.
    func testDecodesLegacyJSONWithoutNewFields() throws {
        let json = """
        [{"id":"1","title":"Legacy","quadrant":"q1","isCompleted":false,"createdAt":"2026-07-01T00:00:00Z"}]
        """.data(using: .utf8)!

        let tasks = try makeDecoder().decode([TaskItem].self, from: json)
        XCTAssertEqual(tasks.count, 1)

        let task = tasks[0]
        XCTAssertEqual(task.id, "1")
        XCTAssertEqual(task.title, "Legacy")
        XCTAssertEqual(task.quadrant, .q1)
        XCTAssertFalse(task.isCompleted)
        XCTAssertNil(task.dueDate)
        XCTAssertNil(task.completedAt)
        XCTAssertNil(task.order)
        XCTAssertTrue(task.subtasks.isEmpty)
    }

    func testFullRoundTrip() throws {
        let original = TaskItem(
            id: "x",
            title: "Full",
            quadrant: .q2,
            isCompleted: true,
            createdAt: Date(timeIntervalSince1970: 100),
            dueDate: Date(timeIntervalSince1970: 200),
            completedAt: Date(timeIntervalSince1970: 300),
            order: 2.0,
            subtasks: [SubTask(id: "s1", title: "Sub", isCompleted: true)]
        )

        let data = try makeEncoder().encode([original])
        let decoded = try makeDecoder().decode([TaskItem].self, from: data)

        XCTAssertEqual(decoded, [original])
    }

    func testDecodesPartialFields() throws {
        // Has subtasks but no due date / order — an intermediate save version.
        let json = """
        [{"id":"2","title":"Mid","quadrant":"q3","isCompleted":false,"createdAt":"2026-07-01T00:00:00Z",
          "subtasks":[{"id":"s","title":"Step","isCompleted":false}]}]
        """.data(using: .utf8)!

        let tasks = try makeDecoder().decode([TaskItem].self, from: json)
        XCTAssertEqual(tasks[0].subtasks.count, 1)
        XCTAssertEqual(tasks[0].subtasks[0].title, "Step")
        XCTAssertNil(tasks[0].order)
        XCTAssertNil(tasks[0].dueDate)
    }
}

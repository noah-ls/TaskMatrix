import XCTest

final class TaskStoreTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TaskMatrixTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func makeStore() -> TaskStore {
        TaskStore(storageDirectory: tempDir, syncsToCloud: false)
    }

    // MARK: - CRUD

    func testAddTask() {
        let store = makeStore()
        store.addTask(title: "Hello", quadrant: .q1)
        XCTAssertEqual(store.tasks.count, 1)
        XCTAssertEqual(store.tasks.first?.title, "Hello")
        XCTAssertEqual(store.tasks.first?.quadrant, .q1)
    }

    func testAddTaskTrimsWhitespaceAndIgnoresEmpty() {
        let store = makeStore()
        store.addTask(title: "   ", quadrant: .q1)
        XCTAssertTrue(store.tasks.isEmpty)

        store.addTask(title: "  Trimmed  ", quadrant: .q1)
        XCTAssertEqual(store.tasks.first?.title, "Trimmed")
    }

    func testUpdateTitle() {
        let store = makeStore()
        store.addTask(title: "Old", quadrant: .q1)
        let id = store.tasks[0].id
        store.updateTitle(id: id, newTitle: "New")
        XCTAssertEqual(store.tasks[0].title, "New")
    }

    func testMoveTaskChangesQuadrant() {
        let store = makeStore()
        store.addTask(title: "T", quadrant: .q1)
        let id = store.tasks[0].id
        store.moveTask(id: id, to: .q3)
        XCTAssertEqual(store.tasks[0].quadrant, .q3)
    }

    func testDeleteTask() {
        let store = makeStore()
        store.addTask(title: "T", quadrant: .q1)
        store.deleteTask(id: store.tasks[0].id)
        XCTAssertTrue(store.tasks.isEmpty)
    }

    // MARK: - Completion

    func testCompleteCascadesToSubtasksAndStampsCompletedAt() {
        let store = makeStore()
        store.addTask(title: "Parent", quadrant: .q1)
        let id = store.tasks[0].id
        store.addSubtask(taskID: id, title: "Sub1")
        store.addSubtask(taskID: id, title: "Sub2")

        store.setTaskCompleted(id: id, isCompleted: true)
        let done = store.task(id: id)!
        XCTAssertTrue(done.isCompleted)
        XCTAssertNotNil(done.completedAt)
        XCTAssertTrue(done.subtasks.allSatisfy(\.isCompleted))

        store.setTaskCompleted(id: id, isCompleted: false)
        XCTAssertNil(store.task(id: id)!.completedAt)
    }

    // MARK: - Subtasks

    func testSubtaskCRUD() {
        let store = makeStore()
        store.addTask(title: "P", quadrant: .q1)
        let id = store.tasks[0].id

        store.addSubtask(taskID: id, title: "S")
        let subID = store.task(id: id)!.subtasks[0].id

        store.updateSubtaskTitle(taskID: id, subtaskID: subID, newTitle: "S2")
        XCTAssertEqual(store.task(id: id)!.subtasks[0].title, "S2")

        store.setSubtaskCompleted(taskID: id, subtaskID: subID, isCompleted: true)
        XCTAssertTrue(store.task(id: id)!.subtasks[0].isCompleted)

        store.deleteSubtask(taskID: id, subtaskID: subID)
        XCTAssertTrue(store.task(id: id)!.subtasks.isEmpty)
    }

    // MARK: - Due date

    func testUpdateDueDate() {
        let store = makeStore()
        store.addTask(title: "T", quadrant: .q1)
        let id = store.tasks[0].id

        let due = Date(timeIntervalSince1970: 1000)
        store.updateDueDate(id: id, dueDate: due)
        XCTAssertEqual(store.task(id: id)!.dueDate, due)

        store.updateDueDate(id: id, dueDate: nil)
        XCTAssertNil(store.task(id: id)!.dueDate)
    }

    // MARK: - Reorder

    /// The view's sort: explicit order first, then createdAt.
    private func openOrder(_ store: TaskStore, _ quadrant: Quadrant) -> [String] {
        store.tasks
            .filter { $0.quadrant == quadrant && !$0.isCompleted }
            .sorted { lhs, rhs in
                if let lo = lhs.order, let ro = rhs.order { return lo < ro }
                if lhs.order != nil { return true }
                if rhs.order != nil { return false }
                return lhs.createdAt < rhs.createdAt
            }
            .map(\.title)
    }

    private func seedFour(_ store: TaskStore) {
        for title in ["A", "B", "C", "D"] {
            store.addTask(title: title, quadrant: .q1)
        }
    }

    private func id(_ store: TaskStore, _ title: String) -> String {
        store.tasks.first { $0.title == title }!.id
    }

    func testReorderToTop() {
        let store = makeStore()
        seedFour(store)
        store.moveTask(id: id(store, "C"), to: .q1, beforeID: id(store, "A"))
        XCTAssertEqual(openOrder(store, .q1), ["C", "A", "B", "D"])
    }

    func testReorderToEnd() {
        let store = makeStore()
        seedFour(store)
        store.moveTask(id: id(store, "A"), to: .q1, beforeID: nil)
        XCTAssertEqual(openOrder(store, .q1), ["B", "C", "D", "A"])
    }

    func testReorderIntoMiddle() {
        let store = makeStore()
        seedFour(store)
        store.moveTask(id: id(store, "D"), to: .q1, beforeID: id(store, "B"))
        XCTAssertEqual(openOrder(store, .q1), ["A", "D", "B", "C"])
    }

    func testReorderOntoSelfIsNoOp() {
        let store = makeStore()
        seedFour(store)
        let bID = id(store, "B")
        store.moveTask(id: bID, to: .q1, beforeID: bID)
        // Array order (append order) is unchanged.
        XCTAssertEqual(store.tasks.map(\.title), ["A", "B", "C", "D"])
    }

    func testCrossQuadrantDropAtPosition() {
        let store = makeStore()
        store.addTask(title: "X", quadrant: .q2)
        store.addTask(title: "Y", quadrant: .q2)
        store.addTask(title: "Z", quadrant: .q1)

        store.moveTask(id: id(store, "Z"), to: .q2, beforeID: id(store, "Y"))
        XCTAssertEqual(openOrder(store, .q2), ["X", "Z", "Y"])
        XCTAssertEqual(store.task(id: id(store, "Z"))!.quadrant, .q2)
    }

    // MARK: - Persistence

    func testPersistenceRoundTrip() {
        let store1 = makeStore()
        store1.addTask(title: "Persisted", quadrant: .q3)

        let store2 = TaskStore(storageDirectory: tempDir, syncsToCloud: false)
        XCTAssertEqual(store2.tasks.count, 1)
        XCTAssertEqual(store2.tasks.first?.title, "Persisted")
        XCTAssertEqual(store2.tasks.first?.quadrant, .q3)
    }

    func testLoadsLegacyJSONFile() throws {
        let legacy = """
        [{"id":"L","title":"Legacy","quadrant":"q4","isCompleted":false,"createdAt":"2026-07-01T00:00:00Z"}]
        """
        try legacy.write(
            to: tempDir.appendingPathComponent("tasks.json"),
            atomically: true,
            encoding: .utf8
        )

        let store = TaskStore(storageDirectory: tempDir, syncsToCloud: false)
        XCTAssertEqual(store.tasks.count, 1)
        XCTAssertEqual(store.tasks[0].quadrant, .q4)
        XCTAssertNil(store.tasks[0].order)
    }
}

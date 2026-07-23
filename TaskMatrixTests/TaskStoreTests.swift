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

    private func writeTasks(_ tasks: [TaskItem]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(tasks)
        try data.write(to: tempDir.appendingPathComponent("tasks.json"), options: .atomic)
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

    /// The view's sort: open first, then pinned, then explicit order/createdAt.
    private func openOrder(_ store: TaskStore, _ quadrant: Quadrant) -> [String] {
        store.tasks
            .filter { $0.quadrant == quadrant && !$0.isCompleted }
            .sorted { $0.sortsBefore($1) }
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

    // MARK: - Pinning

    func testPinTaskMovesItToTopOfOpenGroup() {
        let store = makeStore()
        seedFour(store)

        store.setTaskPinned(id: id(store, "C"), isPinned: true)

        XCTAssertTrue(store.task(id: id(store, "C"))!.isPinned)
        XCTAssertEqual(openOrder(store, .q1), ["C", "A", "B", "D"])
    }

    func testMostRecentlyPinnedTaskBecomesTopPinnedTask() {
        let store = makeStore()
        seedFour(store)

        store.setTaskPinned(id: id(store, "C"), isPinned: true)
        store.setTaskPinned(id: id(store, "B"), isPinned: true)

        XCTAssertEqual(openOrder(store, .q1), ["B", "C", "A", "D"])
    }

    func testUnpinTaskLeavesRemainingPinnedTasksAboveIt() {
        let store = makeStore()
        seedFour(store)

        store.setTaskPinned(id: id(store, "C"), isPinned: true)
        store.setTaskPinned(id: id(store, "B"), isPinned: true)
        store.setTaskPinned(id: id(store, "B"), isPinned: false)

        XCTAssertFalse(store.task(id: id(store, "B"))!.isPinned)
        XCTAssertEqual(openOrder(store, .q1), ["C", "B", "A", "D"])
    }

    // MARK: - Archive

    func testArchiveCompletedTasksOlderThanThreshold() throws {
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 12))!
        let oldCompletedAt = calendar.date(byAdding: .day, value: -16, to: now)!
        let recentCompletedAt = calendar.date(byAdding: .day, value: -14, to: now)!
        let oldCreatedAt = calendar.date(byAdding: .day, value: -30, to: now)!

        try writeTasks([
            TaskItem(
                id: "oldDone",
                title: "Old Done",
                quadrant: .q1,
                isCompleted: true,
                createdAt: oldCreatedAt,
                completedAt: oldCompletedAt,
                isPinned: true
            ),
            TaskItem(
                id: "recentDone",
                title: "Recent Done",
                quadrant: .q1,
                isCompleted: true,
                createdAt: recentCompletedAt,
                completedAt: recentCompletedAt
            ),
            TaskItem(
                id: "oldOpen",
                title: "Old Open",
                quadrant: .q2,
                isCompleted: false,
                createdAt: oldCreatedAt
            )
        ])

        let store = makeStore()
        XCTAssertTrue(store.archiveCompletedTasks(olderThanDays: 15, now: now))

        XCTAssertNotNil(store.task(id: "oldDone")!.archivedAt)
        XCTAssertFalse(store.task(id: "oldDone")!.isPinned)
        XCTAssertNil(store.task(id: "recentDone")!.archivedAt)
        XCTAssertNil(store.task(id: "oldOpen")!.archivedAt)
        XCTAssertEqual(store.activeTasks.map(\.id).sorted(), ["oldOpen", "recentDone"])
        XCTAssertEqual(store.archivedTasks.map(\.id), ["oldDone"])
    }

    func testArchiveTaskMovesActiveTaskToArchive() {
        let store = makeStore()
        store.addTask(title: "Manual Archive", quadrant: .q2)
        let taskID = id(store, "Manual Archive")

        store.setTaskPinned(id: taskID, isPinned: true)
        store.archiveTask(id: taskID, archivedAt: Date(timeIntervalSince1970: 2_000))

        let task = store.task(id: taskID)!
        XCTAssertNotNil(task.archivedAt)
        XCTAssertFalse(task.isPinned)
        XCTAssertTrue(store.activeTasks.isEmpty)
        XCTAssertEqual(store.archivedTasks.map(\.id), [taskID])
    }

    func testRestoreTaskClearsArchiveDate() throws {
        let archivedAt = Date(timeIntervalSince1970: 1000)
        try writeTasks([
            TaskItem(
                id: "archived",
                title: "Archived",
                quadrant: .q3,
                isCompleted: true,
                createdAt: Date(timeIntervalSince1970: 100),
                completedAt: Date(timeIntervalSince1970: 200),
                archivedAt: archivedAt
            )
        ])

        let store = makeStore()
        store.restoreTask(id: "archived")

        XCTAssertNil(store.task(id: "archived")!.archivedAt)
        XCTAssertEqual(store.activeTasks.map(\.id), ["archived"])
        XCTAssertTrue(store.archivedTasks.isEmpty)
    }

    // MARK: - Persistence

    func testPersistenceRoundTrip() {
        let store1 = makeStore()
        store1.addTask(title: "Persisted", quadrant: .q3)
        store1.setTaskPinned(id: id(store1, "Persisted"), isPinned: true)

        let store2 = TaskStore(storageDirectory: tempDir, syncsToCloud: false)
        XCTAssertEqual(store2.tasks.count, 1)
        XCTAssertEqual(store2.tasks.first?.title, "Persisted")
        XCTAssertEqual(store2.tasks.first?.quadrant, .q3)
        XCTAssertTrue(store2.tasks.first?.isPinned == true)
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
        XCTAssertFalse(store.tasks[0].isPinned)
        XCTAssertNil(store.tasks[0].archivedAt)
    }
}

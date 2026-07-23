import Foundation

final class TaskStore {
    var onChange: (([TaskItem]) -> Void)?

    private(set) var tasks: [TaskItem] = []
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let cloudSync: TaskCloudSync?
    /// When set, tasks.json lives here instead of Application Support. Used by
    /// tests to isolate storage in a temporary directory.
    private let storageDirectoryOverride: URL?
    /// Timestamp of the copy we hold; used to decide whether an iCloud
    /// payload is newer than local state (last writer wins).
    private var lastLocalUpdate = Date.distantPast

    var activeTasks: [TaskItem] {
        tasks.filter { !$0.isArchived }
    }

    var archivedTasks: [TaskItem] {
        tasks
            .filter(\.isArchived)
            .sorted { lhs, rhs in
                switch (lhs.archivedAt, rhs.archivedAt) {
                case let (lDate?, rDate?) where lDate != rDate:
                    return lDate > rDate
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                default:
                    return lhs.createdAt > rhs.createdAt
                }
            }
    }

    /// - Parameters:
    ///   - storageDirectory: overrides the on-disk location (default:
    ///     Application Support/TaskMatrix). Tests pass a temp directory.
    ///   - syncsToCloud: when false, skips iCloud entirely (default: true).
    init(storageDirectory: URL? = nil, syncsToCloud: Bool = true) {
        storageDirectoryOverride = storageDirectory
        cloudSync = syncsToCloud ? TaskCloudSync() : nil

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        load()

        // Adopt a newer copy from iCloud at launch, then track pushes
        // arriving from other devices while running.
        if let cloudSync, let envelope = cloudSync.currentEnvelope() {
            adoptIfNewer(envelope)
        }
        cloudSync?.onRemoteChange = { [weak self] envelope in
            self?.adoptIfNewer(envelope)
        }
    }

    func addTask(title: String, quadrant: Quadrant, dueDate: Date? = nil) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        tasks.append(
            TaskItem(
                id: UUID().uuidString,
                title: trimmedTitle,
                quadrant: quadrant,
                isCompleted: false,
                createdAt: Date(),
                dueDate: dueDate
            )
        )
        persistAndNotify()
    }

    func updateDueDate(id: String, dueDate: Date?) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }

        tasks[index].dueDate = dueDate
        persistAndNotify()
    }

    func updateTitle(id: String, newTitle: String) {
        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }

        tasks[index].title = trimmedTitle
        persistAndNotify()
    }

    /// Moves a task into `quadrant`, optionally positioning it before the task
    /// with `beforeID` (nil appends to the end of its group). Reordering within
    /// the same quadrant is just this with the current quadrant. Explicit
    /// `order` values are reassigned across the destination group so the new
    /// arrangement survives re-renders and reloads.
    func moveTask(id: String, to quadrant: Quadrant, beforeID: String? = nil) {
        guard let taskIndex = tasks.firstIndex(where: { $0.id == id }) else { return }
        // Dropping onto itself keeps the current position.
        if beforeID == id && tasks[taskIndex].quadrant == quadrant { return }

        let completionState = tasks[taskIndex].isCompleted
        tasks[taskIndex].quadrant = quadrant

        var orderedIDs = sortedTaskIDs(in: quadrant, isCompleted: completionState).filter { $0 != id }
        if let beforeID = beforeID, beforeID != id,
           let insertIndex = orderedIDs.firstIndex(of: beforeID) {
            orderedIDs.insert(id, at: insertIndex)
        } else {
            orderedIDs.append(id)
        }

        assignOrder(orderedIDs)

        persistAndNotify()
    }

    func setTaskPinned(id: String, isPinned: Bool) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        guard tasks[index].isPinned != isPinned else { return }

        let quadrant = tasks[index].quadrant
        let completionState = tasks[index].isCompleted
        tasks[index].isPinned = isPinned

        let currentIDs = sortedTaskIDs(in: quadrant, isCompleted: completionState).filter { $0 != id }
        let pinnedIDs = currentIDs.filter { task(id: $0)?.isPinned == true }
        let unpinnedIDs = currentIDs.filter { task(id: $0)?.isPinned != true }
        let orderedIDs = isPinned
            ? [id] + pinnedIDs + unpinnedIDs
            : pinnedIDs + [id] + unpinnedIDs

        assignOrder(orderedIDs)

        persistAndNotify()
    }

    func setTaskCompleted(id: String, isCompleted: Bool) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }

        tasks[index].isCompleted = isCompleted
        tasks[index].completedAt = isCompleted ? Date() : nil
        for subIndex in tasks[index].subtasks.indices {
            tasks[index].subtasks[subIndex].isCompleted = isCompleted
        }
        persistAndNotify()
    }

    func deleteTask(id: String) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }

        tasks.remove(at: index)
        persistAndNotify()
    }

    func archiveTask(id: String, archivedAt: Date = Date()) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        guard tasks[index].archivedAt == nil else { return }

        tasks[index].archivedAt = archivedAt
        tasks[index].isPinned = false
        persistAndNotify()
    }

    @discardableResult
    func archiveCompletedTasks(olderThanDays days: Int, now: Date = Date()) -> Bool {
        guard days > 0 else { return false }

        let calendar = Calendar.current
        guard let cutoffDay = calendar.date(
            byAdding: .day,
            value: -days,
            to: calendar.startOfDay(for: now)
        ) else {
            return false
        }

        var didArchive = false
        for index in tasks.indices {
            guard tasks[index].archivedAt == nil, tasks[index].isCompleted else { continue }

            let archiveReference = tasks[index].completedAt ?? tasks[index].createdAt
            guard calendar.startOfDay(for: archiveReference) <= cutoffDay else { continue }

            tasks[index].archivedAt = now
            tasks[index].isPinned = false
            didArchive = true
        }

        if didArchive {
            persistAndNotify()
        }
        return didArchive
    }

    func restoreTask(id: String) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        guard tasks[index].archivedAt != nil else { return }

        tasks[index].archivedAt = nil
        persistAndNotify()
    }

    func addSubtask(taskID: String, title: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }

        tasks[index].subtasks.append(
            SubTask(id: UUID().uuidString, title: trimmedTitle, isCompleted: false)
        )
        persistAndNotify()
    }

    func updateSubtaskTitle(taskID: String, subtaskID: String, newTitle: String) {
        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        guard let index = tasks.firstIndex(where: { $0.id == taskID }),
              let subIndex = tasks[index].subtasks.firstIndex(where: { $0.id == subtaskID }) else {
            return
        }

        tasks[index].subtasks[subIndex].title = trimmedTitle
        persistAndNotify()
    }

    func setSubtaskCompleted(taskID: String, subtaskID: String, isCompleted: Bool) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }),
              let subIndex = tasks[index].subtasks.firstIndex(where: { $0.id == subtaskID }) else {
            return
        }

        tasks[index].subtasks[subIndex].isCompleted = isCompleted
        persistAndNotify()
    }

    func deleteSubtask(taskID: String, subtaskID: String) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }),
              let subIndex = tasks[index].subtasks.firstIndex(where: { $0.id == subtaskID }) else {
            return
        }

        tasks[index].subtasks.remove(at: subIndex)
        persistAndNotify()
    }

    func task(id: String) -> TaskItem? {
        tasks.first(where: { $0.id == id })
    }

    private func sortedTaskIDs(in quadrant: Quadrant, isCompleted: Bool) -> [String] {
        tasks
            .filter { $0.quadrant == quadrant && $0.isCompleted == isCompleted }
            .sorted { $0.sortsBefore($1) }
            .map(\.id)
    }

    private func assignOrder(_ orderedIDs: [String]) {
        for (rank, id) in orderedIDs.enumerated() {
            guard let index = tasks.firstIndex(where: { $0.id == id }) else { continue }
            tasks[index].order = Double(rank)
        }
    }

    private func persistAndNotify() {
        lastLocalUpdate = Date()
        save()
        cloudSync?.push(tasks: tasks, updatedAt: lastLocalUpdate)
        onChange?(tasks)
    }

    private func adoptIfNewer(_ envelope: TaskCloudSync.Envelope) {
        guard envelope.updatedAt > lastLocalUpdate else { return }

        tasks = envelope.tasks
        lastLocalUpdate = envelope.updatedAt
        save()   // local file only — pushing back would echo the change
        onChange?(tasks)
    }

    private func load() {
        let url = storageURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            onChange?(tasks)
            return
        }

        do {
            let data = try Data(contentsOf: url)
            tasks = try decoder.decode([TaskItem].self, from: data)

            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            if let modified = attributes?[.modificationDate] as? Date {
                lastLocalUpdate = modified
            }
        } catch {
            NSLog("[TaskStore] Failed loading tasks: \(error.localizedDescription)")
            tasks = []
        }

        onChange?(tasks)
    }

    private func save() {
        let url = storageURL()

        do {
            let data = try encoder.encode(tasks)
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("[TaskStore] Failed saving tasks: \(error.localizedDescription)")
        }
    }

    private func storageURL() -> URL {
        let fileManager = FileManager.default
        let directory: URL
        if let storageDirectoryOverride {
            directory = storageDirectoryOverride
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            directory = appSupport.appendingPathComponent("TaskMatrix", isDirectory: true)
        }

        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory.appendingPathComponent("tasks.json", isDirectory: false)
    }
}

import Foundation

final class TaskStore {
    var onChange: (([TaskItem]) -> Void)?

    private(set) var tasks: [TaskItem] = []
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let cloudSync = TaskCloudSync()
    /// Timestamp of the copy we hold; used to decide whether an iCloud
    /// payload is newer than local state (last writer wins).
    private var lastLocalUpdate = Date.distantPast

    init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        load()

        // Adopt a newer copy from iCloud at launch, then track pushes
        // arriving from other devices while running.
        if let envelope = cloudSync.currentEnvelope() {
            adoptIfNewer(envelope)
        }
        cloudSync.onRemoteChange = { [weak self] envelope in
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

    func reorderTask(id: String, beforeID: String?) {
        guard let fromIndex = tasks.firstIndex(where: { $0.id == id }) else { return }
        let task = tasks[fromIndex]

        let toIndex: Int
        if let beforeID = beforeID, let idx = tasks.firstIndex(where: { $0.id == beforeID }) {
            toIndex = idx
        } else {
            toIndex = tasks.count
        }

        guard toIndex != fromIndex && toIndex != fromIndex + 1 else { return }

        tasks.remove(at: fromIndex)
        let insertIndex = toIndex > fromIndex ? toIndex - 1 : toIndex
        tasks.insert(task, at: insertIndex)

        // Assign explicit order values to tasks with the same completion state
        // and quadrant so they sort consistently when not dragging.
        let sameGroupIndices = tasks.indices.filter { i in
            tasks[i].isCompleted == task.isCompleted && tasks[i].quadrant == task.quadrant
        }

        for (rank, idx) in sameGroupIndices.enumerated() {
            tasks[idx].order = Double(rank)
        }

        persistAndNotify()
    }

    func updateTitle(id: String, newTitle: String) {
        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }

        tasks[index].title = trimmedTitle
        persistAndNotify()
    }

    func moveTask(id: String, to quadrant: Quadrant) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }

        tasks[index].quadrant = quadrant
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

    private func persistAndNotify() {
        lastLocalUpdate = Date()
        save()
        cloudSync.push(tasks: tasks, updatedAt: lastLocalUpdate)
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
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let directory = appSupport.appendingPathComponent("TaskMatrix", isDirectory: true)

        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory.appendingPathComponent("tasks.json", isDirectory: false)
    }
}

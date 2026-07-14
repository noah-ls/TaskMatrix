import Foundation

final class TaskStore {
    var onChange: (([TaskItem]) -> Void)?

    private(set) var tasks: [TaskItem] = []
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        load()
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
        save()
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

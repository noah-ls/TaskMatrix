import Foundation

struct SubTask: Codable, Equatable {
    let id: String
    var title: String
    var isCompleted: Bool
}

struct TaskItem: Codable, Equatable {
    let id: String
    var title: String
    var quadrant: Quadrant
    var isCompleted: Bool
    let createdAt: Date
    /// Date-only deadline (start of day); nil when no due date is set.
    var dueDate: Date?
    var subtasks: [SubTask]

    init(
        id: String,
        title: String,
        quadrant: Quadrant,
        isCompleted: Bool,
        createdAt: Date,
        dueDate: Date? = nil,
        subtasks: [SubTask] = []
    ) {
        self.id = id
        self.title = title
        self.quadrant = quadrant
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.subtasks = subtasks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        quadrant = try container.decode(Quadrant.self, forKey: .quadrant)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        // Older saves predate these fields; default gracefully.
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        subtasks = try container.decodeIfPresent([SubTask].self, forKey: .subtasks) ?? []
    }
}

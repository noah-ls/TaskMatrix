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
    /// When the task was checked off; nil while it is open.
    var completedAt: Date?
    /// User-defined sort order within the task's completion state and quadrant;
    /// nil means use createdAt. When dragging to reorder, we assign explicit
    /// order values to the affected tasks.
    var order: Double?
    /// Pinned tasks sort above unpinned tasks within the same quadrant and
    /// completion state. Older saves default this to false.
    var isPinned: Bool
    /// When non-nil, the task is hidden from the active matrix and appears in
    /// the archive list.
    var archivedAt: Date?
    var subtasks: [SubTask]

    var isArchived: Bool {
        archivedAt != nil
    }

    init(
        id: String,
        title: String,
        quadrant: Quadrant,
        isCompleted: Bool,
        createdAt: Date,
        dueDate: Date? = nil,
        completedAt: Date? = nil,
        order: Double? = nil,
        isPinned: Bool = false,
        archivedAt: Date? = nil,
        subtasks: [SubTask] = []
    ) {
        self.id = id
        self.title = title
        self.quadrant = quadrant
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.completedAt = completedAt
        self.order = order
        self.isPinned = isPinned
        self.archivedAt = archivedAt
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
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        order = try container.decodeIfPresent(Double.self, forKey: .order)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt)
        subtasks = try container.decodeIfPresent([SubTask].self, forKey: .subtasks) ?? []
    }

    func sortsBefore(_ other: TaskItem) -> Bool {
        if isCompleted != other.isCompleted {
            return !isCompleted
        }
        if isPinned != other.isPinned {
            return isPinned
        }
        if let lOrder = order, let rOrder = other.order {
            return lOrder < rOrder
        }
        if order != nil {
            return true
        }
        if other.order != nil {
            return false
        }
        if createdAt != other.createdAt {
            return createdAt < other.createdAt
        }
        return id < other.id
    }
}

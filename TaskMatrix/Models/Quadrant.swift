import Foundation

enum Quadrant: String, CaseIterable, Codable {
    case q1
    case q2
    case q3
    case q4

    var title: String {
        switch self {
        case .q1:
            return "Important + Urgent"
        case .q2:
            return "Important + Not Urgent"
        case .q3:
            return "Not Important + Urgent"
        case .q4:
            return "Not Important + Not Urgent"
        }
    }

    var strategy: String {
        switch self {
        case .q1:
            return "Do First"
        case .q2:
            return "Schedule"
        case .q3:
            return "Delegate"
        case .q4:
            return "Eliminate"
        }
    }

    var subtitle: String {
        switch self {
        case .q1:
            return "IMPORTANT · URGENT"
        case .q2:
            return "IMPORTANT · NOT URGENT"
        case .q3:
            return "NOT IMPORTANT · URGENT"
        case .q4:
            return "NOT IMPORTANT · NOT URGENT"
        }
    }
}

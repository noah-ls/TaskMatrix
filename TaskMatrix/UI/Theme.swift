import Cocoa

extension NSColor {
    static let taskCanvas = NSColor(red: 0.957, green: 0.961, blue: 0.945, alpha: 1)

    static let taskInk = NSColor(red: 0.055, green: 0.059, blue: 0.047, alpha: 1)
    static let taskMuted = NSColor(red: 0.42, green: 0.45, blue: 0.41, alpha: 1)

    static let taskAccent = NSColor(red: 0.624, green: 0.909, blue: 0.439, alpha: 1)
    static let taskAccentText = NSColor(red: 0.086, green: 0.200, blue: 0.0, alpha: 1)

    static let taskRing = NSColor(red: 0.055, green: 0.059, blue: 0.047, alpha: 0.10)
    static let taskSurface = NSColor.white
    static let taskSurfaceHover = NSColor.white

    static let taskOverdue = NSColor(red: 0.898, green: 0.283, blue: 0.302, alpha: 1)
    static let taskDueToday = NSColor(red: 0.792, green: 0.557, blue: 0.0, alpha: 1)
}

extension Quadrant {
    var accentColor: NSColor {
        switch self {
        case .q1:
            return NSColor(red: 0.898, green: 0.283, blue: 0.302, alpha: 1)   // red — act now
        case .q2:
            return NSColor(red: 0.455, green: 0.753, blue: 0.263, alpha: 1)   // green — plan
        case .q3:
            return NSColor(red: 0.961, green: 0.702, blue: 0.004, alpha: 1)   // amber — hand off
        case .q4:
            return NSColor(red: 0.608, green: 0.627, blue: 0.588, alpha: 1)   // gray — drop
        }
    }

    /// Mark color for charts: the amber accent is too light against white
    /// at bar weight, so quadrant 3 darkens; others reuse the accent.
    var chartColor: NSColor {
        self == .q3 ? NSColor.taskDueToday : accentColor
    }

    var surfaceColor: NSColor {
        switch self {
        case .q1:
            return NSColor(red: 0.996, green: 0.949, blue: 0.941, alpha: 1)   // soft red
        case .q2:
            return NSColor(red: 0.945, green: 0.977, blue: 0.925, alpha: 1)   // soft green
        case .q3:
            return NSColor(red: 0.996, green: 0.969, blue: 0.902, alpha: 1)   // soft amber
        case .q4:
            return NSColor(red: 0.949, green: 0.953, blue: 0.941, alpha: 1)   // soft gray
        }
    }
}

extension NSPasteboard.PasteboardType {
    static let taskID = NSPasteboard.PasteboardType("com.taskmatrix.task-id")
}

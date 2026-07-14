import Foundation

enum DueDateFormatting {
    /// Short human label: "Today", "Tomorrow", "Yesterday", "Jul 20",
    /// or "Jul 20, 2027" outside the current year.
    static func shortLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }

        let formatter = DateFormatter()
        formatter.dateFormat = calendar.isDate(date, equalTo: Date(), toGranularity: .year)
            ? "MMM d"
            : "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

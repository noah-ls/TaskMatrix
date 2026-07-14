import Foundation

struct StatsSummary {
    struct QuadrantSlice {
        let quadrant: Quadrant
        let openCount: Int
    }

    struct DailyCount {
        let date: Date
        let count: Int
    }

    let openCount: Int
    let completedCount: Int
    let overdueCount: Int
    /// Share of completed tasks (that had a due date) finished on or before
    /// it; nil when no completed task had a due date.
    let onTimeRate: Double?
    let quadrantSlices: [QuadrantSlice]
    /// Oldest first, one entry per day, 14 entries.
    let dailyCompletions: [DailyCount]
    let insight: String
}

enum StatsCalculator {
    static func summarize(_ tasks: [TaskItem], now: Date = Date()) -> StatsSummary {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        let open = tasks.filter { !$0.isCompleted }
        let completed = tasks.filter { $0.isCompleted }

        let overdueCount = open.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate < today
        }.count

        let completedWithDue = completed.filter { $0.dueDate != nil && $0.completedAt != nil }
        var onTimeRate: Double?
        if !completedWithDue.isEmpty {
            let onTimeCount = completedWithDue.filter { task in
                guard let dueDate = task.dueDate, let completedAt = task.completedAt else { return false }
                return calendar.startOfDay(for: completedAt) <= dueDate
            }.count
            onTimeRate = Double(onTimeCount) / Double(completedWithDue.count)
        }

        let slices = Quadrant.allCases.map { quadrant in
            StatsSummary.QuadrantSlice(
                quadrant: quadrant,
                openCount: open.filter { $0.quadrant == quadrant }.count
            )
        }

        let dailyCompletions: [StatsSummary.DailyCount] = (0..<14).reversed().map { daysAgo in
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            let count = completed.filter { task in
                guard let completedAt = task.completedAt else { return false }
                return calendar.isDate(completedAt, inSameDayAs: day)
            }.count
            return StatsSummary.DailyCount(date: day, count: count)
        }

        return StatsSummary(
            openCount: open.count,
            completedCount: completed.count,
            overdueCount: overdueCount,
            onTimeRate: onTimeRate,
            quadrantSlices: slices,
            dailyCompletions: dailyCompletions,
            insight: insight(openTotal: open.count, slices: slices, overdueCount: overdueCount)
        )
    }

    private static func insight(openTotal: Int, slices: [StatsSummary.QuadrantSlice], overdueCount: Int) -> String {
        guard openTotal > 0 else {
            return "All clear — no open tasks. Add what matters next."
        }

        func share(_ quadrant: Quadrant) -> Double {
            let count = slices.first { $0.quadrant == quadrant }?.openCount ?? 0
            return Double(count) / Double(openTotal)
        }

        if Double(overdueCount) / Double(openTotal) >= 0.3 {
            return "A large share of open tasks is overdue — clear or reschedule the red ones first."
        }
        if share(.q1) >= 0.5 {
            return "Over half of your open tasks are urgent and important — that's firefighting. Catch work earlier, while it's still Schedule material."
        }
        if share(.q4) >= 0.4 {
            return "Many open tasks are neither important nor urgent — consider eliminating them outright."
        }
        if share(.q2) >= 0.4 {
            return "Most open work is important but not yet urgent — the healthy place to be. Keep scheduling."
        }
        return "Open tasks are spread across the matrix — review each quadrant and act by its strategy."
    }
}

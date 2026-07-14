import Cocoa

/// Standalone statistics page: KPI tiles, open tasks by quadrant, and a
/// 14-day completion trend. Lives in its own window.
final class StatsViewController: NSViewController {
    private let contentStack = NSStackView()
    private var tasks: [TaskItem] = []

    func update(tasks: [TaskItem]) {
        self.tasks = tasks
        if isViewLoaded {
            rebuild()
        }
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 584))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.taskCanvas.cgColor

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 14

        view.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22),
            contentStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -16)
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        rebuild()
    }

    // MARK: - Building

    private func rebuild() {
        contentStack.arrangedSubviews.forEach { subview in
            contentStack.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        let summary = StatsCalculator.summarize(tasks)

        let header = makeHeader()
        contentStack.addArrangedSubview(header)

        let kpiRow = makeKPIRow(summary)
        contentStack.addArrangedSubview(kpiRow)
        kpiRow.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true

        let quadrantCard = makeQuadrantCard(summary)
        contentStack.addArrangedSubview(quadrantCard)
        quadrantCard.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true

        let trendCard = makeTrendCard(summary)
        contentStack.addArrangedSubview(trendCard)
        trendCard.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
    }

    private func makeHeader() -> NSView {
        let titleLabel = NSTextField(labelWithString: "Statistics")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 19, weight: .black)
        titleLabel.textColor = NSColor.taskInk

        let subtitleLabel = NSTextField(labelWithString: "How your matrix is doing.")
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .systemFont(ofSize: 11.5, weight: .medium)
        subtitleLabel.textColor = NSColor.taskMuted

        let stack = NSStackView(views: [titleLabel, subtitleLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 1
        return stack
    }

    // MARK: - KPI tiles

    private func makeKPIRow(_ summary: StatsSummary) -> NSView {
        let onTimeText: String
        if let rate = summary.onTimeRate {
            onTimeText = "\(Int((rate * 100).rounded()))%"
        } else {
            onTimeText = "—"
        }

        let tiles = [
            makeTile(value: "\(summary.openCount)", label: "OPEN"),
            makeTile(value: "\(summary.completedCount)", label: "COMPLETED"),
            makeTile(
                value: "\(summary.overdueCount)",
                label: "OVERDUE",
                valueColor: summary.overdueCount > 0 ? .taskOverdue : .taskInk
            ),
            makeTile(value: onTimeText, label: "ON-TIME RATE")
        ]

        let row = NSStackView(views: tiles)
        row.translatesAutoresizingMaskIntoConstraints = false
        row.orientation = .horizontal
        row.distribution = .fillEqually
        row.spacing = 10
        return row
    }

    private func makeTile(value: String, label: String, valueColor: NSColor = .taskInk) -> NSView {
        let card = makeCard()

        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 24, weight: .black)
        valueLabel.textColor = valueColor

        let captionLabel = makeSectionLabel(label)

        let stack = NSStackView(views: [valueLabel, captionLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])
        return card
    }

    // MARK: - Quadrant distribution

    private func makeQuadrantCard(_ summary: StatsSummary) -> NSView {
        let card = makeCard()

        let titleLabel = makeSectionLabel("OPEN TASKS BY QUADRANT")

        let maxCount = max(summary.quadrantSlices.map(\.openCount).max() ?? 0, 1)

        let rowsStack = NSStackView()
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        rowsStack.orientation = .vertical
        rowsStack.alignment = .leading
        rowsStack.spacing = 9

        for slice in summary.quadrantSlices {
            let row = makeQuadrantRow(slice: slice, maxCount: maxCount)
            rowsStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: rowsStack.widthAnchor).isActive = true
        }

        let separator = NSView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.taskRing.cgColor

        let insightLabel = NSTextField(wrappingLabelWithString: summary.insight)
        insightLabel.translatesAutoresizingMaskIntoConstraints = false
        insightLabel.font = .systemFont(ofSize: 11.5, weight: .medium)
        insightLabel.textColor = NSColor.taskMuted
        insightLabel.isEditable = false
        insightLabel.isSelectable = false

        card.addSubview(titleLabel)
        card.addSubview(rowsStack)
        card.addSubview(separator)
        card.addSubview(insightLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 13),

            rowsStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            rowsStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            rowsStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 11),

            separator.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            separator.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            separator.topAnchor.constraint(equalTo: rowsStack.bottomAnchor, constant: 12),
            separator.heightAnchor.constraint(equalToConstant: 1),

            insightLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            insightLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            insightLabel.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 10),
            insightLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -13)
        ])
        return card
    }

    private func makeQuadrantRow(slice: StatsSummary.QuadrantSlice, maxCount: Int) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let dot = NSView()
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.wantsLayer = true
        dot.layer?.backgroundColor = slice.quadrant.chartColor.cgColor
        dot.layer?.cornerRadius = 4

        let nameLabel = NSTextField(labelWithString: slice.quadrant.strategy)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        nameLabel.textColor = NSColor.taskInk

        let track = NSView()
        track.translatesAutoresizingMaskIntoConstraints = false
        track.wantsLayer = true
        track.layer?.cornerRadius = 4
        track.layer?.backgroundColor = NSColor.taskInk.withAlphaComponent(0.04).cgColor

        let bar = NSView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.wantsLayer = true
        bar.layer?.cornerRadius = 4
        bar.layer?.backgroundColor = slice.quadrant.chartColor.cgColor

        track.addSubview(bar)

        let countLabel = NSTextField(labelWithString: "\(slice.openCount)")
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.font = .monospacedDigitSystemFont(ofSize: 11.5, weight: .bold)
        countLabel.textColor = NSColor.taskInk
        countLabel.alignment = .right

        row.addSubview(dot)
        row.addSubview(nameLabel)
        row.addSubview(track)
        row.addSubview(countLabel)

        let ratio = CGFloat(slice.openCount) / CGFloat(maxCount)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 18),

            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),
            dot.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            dot.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            nameLabel.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 7),
            nameLabel.widthAnchor.constraint(equalToConstant: 78),
            nameLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            track.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 10),
            track.trailingAnchor.constraint(equalTo: countLabel.leadingAnchor, constant: -12),
            track.heightAnchor.constraint(equalToConstant: 14),
            track.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            bar.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            bar.topAnchor.constraint(equalTo: track.topAnchor),
            bar.bottomAnchor.constraint(equalTo: track.bottomAnchor),
            bar.widthAnchor.constraint(equalTo: track.widthAnchor, multiplier: max(ratio, 0.001)),

            countLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            countLabel.widthAnchor.constraint(equalToConstant: 26),
            countLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])
        return row
    }

    // MARK: - Completion trend

    private func makeTrendCard(_ summary: StatsSummary) -> NSView {
        let card = makeCard()

        let total = summary.dailyCompletions.reduce(0) { $0 + $1.count }
        let titleLabel = makeSectionLabel("COMPLETED — LAST 14 DAYS")
        let totalLabel = NSTextField(labelWithString: "\(total) total")
        totalLabel.translatesAutoresizingMaskIntoConstraints = false
        totalLabel.font = .monospacedDigitSystemFont(ofSize: 10.5, weight: .bold)
        totalLabel.textColor = NSColor.taskMuted

        let maxCount = max(summary.dailyCompletions.map(\.count).max() ?? 0, 1)
        let chartHeight: CGFloat = 104

        let barsRow = NSStackView()
        barsRow.translatesAutoresizingMaskIntoConstraints = false
        barsRow.orientation = .horizontal
        barsRow.distribution = .fillEqually
        barsRow.spacing = 4

        let labelsRow = NSStackView()
        labelsRow.translatesAutoresizingMaskIntoConstraints = false
        labelsRow.orientation = .horizontal
        labelsRow.distribution = .fillEqually
        labelsRow.spacing = 4

        let calendar = Calendar.current
        let maxIndex = summary.dailyCompletions.firstIndex { $0.count == maxCount }

        for (index, day) in summary.dailyCompletions.enumerated() {
            let column = NSView()
            column.translatesAutoresizingMaskIntoConstraints = false

            let bar = NSView()
            bar.translatesAutoresizingMaskIntoConstraints = false
            bar.wantsLayer = true
            bar.layer?.cornerRadius = 3

            let barHeight: CGFloat
            if day.count == 0 {
                bar.layer?.backgroundColor = NSColor.taskInk.withAlphaComponent(0.06).cgColor
                barHeight = 3
            } else {
                bar.layer?.backgroundColor = Quadrant.q2.chartColor.cgColor
                barHeight = max(chartHeight * CGFloat(day.count) / CGFloat(maxCount), 6)
            }

            column.addSubview(bar)
            NSLayoutConstraint.activate([
                bar.leadingAnchor.constraint(equalTo: column.leadingAnchor, constant: 2),
                bar.trailingAnchor.constraint(equalTo: column.trailingAnchor, constant: -2),
                bar.bottomAnchor.constraint(equalTo: column.bottomAnchor),
                bar.heightAnchor.constraint(equalToConstant: barHeight)
            ])

            // Selective direct label: only the busiest day carries its value.
            if index == maxIndex, day.count > 0 {
                let valueLabel = NSTextField(labelWithString: "\(day.count)")
                valueLabel.translatesAutoresizingMaskIntoConstraints = false
                valueLabel.font = .monospacedDigitSystemFont(ofSize: 9.5, weight: .bold)
                valueLabel.textColor = NSColor.taskMuted
                column.addSubview(valueLabel)
                NSLayoutConstraint.activate([
                    valueLabel.centerXAnchor.constraint(equalTo: column.centerXAnchor),
                    valueLabel.bottomAnchor.constraint(equalTo: bar.topAnchor, constant: -2)
                ])
            }

            barsRow.addArrangedSubview(column)

            let dayLabel = NSTextField(labelWithString: "\(calendar.component(.day, from: day.date))")
            dayLabel.translatesAutoresizingMaskIntoConstraints = false
            dayLabel.font = .monospacedDigitSystemFont(ofSize: 8.5, weight: .semibold)
            dayLabel.textColor = NSColor.taskMuted.withAlphaComponent(0.8)
            dayLabel.alignment = .center
            labelsRow.addArrangedSubview(dayLabel)
        }

        card.addSubview(titleLabel)
        card.addSubview(totalLabel)
        card.addSubview(barsRow)
        card.addSubview(labelsRow)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 13),

            totalLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            totalLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            barsRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            barsRow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            barsRow.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 22),
            barsRow.heightAnchor.constraint(equalToConstant: chartHeight),

            labelsRow.leadingAnchor.constraint(equalTo: barsRow.leadingAnchor),
            labelsRow.trailingAnchor.constraint(equalTo: barsRow.trailingAnchor),
            labelsRow.topAnchor.constraint(equalTo: barsRow.bottomAnchor, constant: 4),
            labelsRow.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])
        return card
    }

    // MARK: - Shared pieces

    private func makeCard() -> NSView {
        let card = NSView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.wantsLayer = true
        card.layer?.cornerRadius = 14
        card.layer?.backgroundColor = NSColor.taskSurface.cgColor
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.taskRing.cgColor
        return card
    }

    private func makeSectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        let attributed = NSMutableAttributedString(string: text)
        attributed.addAttributes(
            [
                .font: NSFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: NSColor.taskMuted,
                .kern: 0.7
            ],
            range: NSRange(location: 0, length: attributed.length)
        )
        label.attributedStringValue = attributed
        return label
    }
}

import Cocoa

/// Month calendar for picking a single day, styled to match the app:
/// white card, chevron month navigation, hover states, lime selection,
/// and a ring marking today.
final class CalendarPickerView: NSView {
    var onDateSelected: ((Date) -> Void)?

    var selectedDate: Date? {
        didSet {
            if let selectedDate {
                displayedMonth = Self.monthStart(for: selectedDate)
            }
            rebuildDayGrid()
        }
    }

    private var displayedMonth = CalendarPickerView.monthStart(for: Date()) {
        didSet { rebuildDayGrid() }
    }

    private let monthLabel = NSTextField(labelWithString: "")
    private let dayGridStack = NSStackView()

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupUI()
        rebuildDayGrid()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.backgroundColor = NSColor.taskSurface.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.taskRing.cgColor

        monthLabel.translatesAutoresizingMaskIntoConstraints = false
        monthLabel.font = .systemFont(ofSize: 13, weight: .bold)
        monthLabel.textColor = NSColor.taskInk

        let headerSpacer = NSView()
        headerSpacer.translatesAutoresizingMaskIntoConstraints = false
        headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        headerSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let previousButton = makeChevronButton(symbolName: "chevron.left", action: #selector(handlePreviousMonth(_:)))
        let nextButton = makeChevronButton(symbolName: "chevron.right", action: #selector(handleNextMonth(_:)))

        let headerRow = NSStackView(views: [monthLabel, headerSpacer, previousButton, nextButton])
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 4

        let weekdayRow = NSStackView()
        weekdayRow.translatesAutoresizingMaskIntoConstraints = false
        weekdayRow.orientation = .horizontal
        weekdayRow.distribution = .fillEqually
        weekdayRow.spacing = 0

        let calendar = Calendar.current
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        for offset in 0..<7 {
            let symbol = symbols[(calendar.firstWeekday - 1 + offset) % 7]
            let label = NSTextField(labelWithString: symbol)
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .systemFont(ofSize: 10, weight: .bold)
            label.textColor = NSColor.taskMuted
            label.alignment = .center
            weekdayRow.addArrangedSubview(label)
        }

        dayGridStack.translatesAutoresizingMaskIntoConstraints = false
        dayGridStack.orientation = .vertical
        dayGridStack.distribution = .fillEqually
        dayGridStack.spacing = 2

        addSubview(headerRow)
        addSubview(weekdayRow)
        addSubview(dayGridStack)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 296),

            headerRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            headerRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            headerRow.topAnchor.constraint(equalTo: topAnchor, constant: 10),

            weekdayRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            weekdayRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            weekdayRow.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 8),

            dayGridStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            dayGridStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            dayGridStack.topAnchor.constraint(equalTo: weekdayRow.bottomAnchor, constant: 4),
            dayGridStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            dayGridStack.heightAnchor.constraint(equalToConstant: 6 * 30 + 5 * 2)
        ])
    }

    private func makeChevronButton(symbolName: String, action: Selector) -> NSButton {
        let button = NSButton(title: "", target: self, action: action)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = false
        button.imagePosition = .imageOnly
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        button.contentTintColor = NSColor.taskMuted
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 24),
            button.heightAnchor.constraint(equalToConstant: 24)
        ])
        return button
    }

    private func rebuildDayGrid() {
        let calendar = Calendar.current

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        monthLabel.stringValue = formatter.string(from: displayedMonth)

        dayGridStack.arrangedSubviews.forEach { subview in
            dayGridStack.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        let monthWeekday = calendar.component(.weekday, from: displayedMonth)
        let leadingDays = (monthWeekday - calendar.firstWeekday + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -leadingDays, to: displayedMonth) else { return }

        let today = calendar.startOfDay(for: Date())

        for week in 0..<6 {
            let weekRow = NSStackView()
            weekRow.translatesAutoresizingMaskIntoConstraints = false
            weekRow.orientation = .horizontal
            weekRow.distribution = .fillEqually
            weekRow.spacing = 0

            for day in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: week * 7 + day, to: gridStart) else { continue }

                let cell = CalendarDayCell(
                    date: date,
                    dayNumber: calendar.component(.day, from: date),
                    isCurrentMonth: calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month),
                    isToday: date == today,
                    isSelected: selectedDate.map { calendar.isDate(date, inSameDayAs: $0) } ?? false
                )
                cell.onClick = { [weak self] clicked in
                    self?.selectedDate = clicked
                    self?.onDateSelected?(clicked)
                }
                weekRow.addArrangedSubview(cell)
            }

            dayGridStack.addArrangedSubview(weekRow)
            weekRow.widthAnchor.constraint(equalTo: dayGridStack.widthAnchor).isActive = true
        }
    }

    private static func monthStart(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    @objc
    private func handlePreviousMonth(_ sender: NSButton) {
        displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
    }

    @objc
    private func handleNextMonth(_ sender: NSButton) {
        displayedMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
    }
}

/// One day in the calendar grid.
private final class CalendarDayCell: NSView {
    var onClick: ((Date) -> Void)?

    private let date: Date
    private let isSelected: Bool
    private var isHovering = false
    private var trackingAreaRef: NSTrackingArea?

    private let label = NSTextField(labelWithString: "")

    init(date: Date, dayNumber: Int, isCurrentMonth: Bool, isToday: Bool, isSelected: Bool) {
        self.date = date
        self.isSelected = isSelected
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 8

        label.translatesAutoresizingMaskIntoConstraints = false
        label.stringValue = "\(dayNumber)"
        label.alignment = .center

        if isSelected {
            label.font = .systemFont(ofSize: 12, weight: .bold)
            label.textColor = NSColor.taskAccentText
            layer?.backgroundColor = NSColor.taskAccent.cgColor
        } else if isToday {
            label.font = .systemFont(ofSize: 12, weight: .bold)
            label.textColor = NSColor.taskAccentText
            layer?.borderWidth = 1.5
            layer?.borderColor = NSColor.taskAccent.cgColor
        } else {
            label.font = .systemFont(ofSize: 12, weight: .medium)
            label.textColor = isCurrentMonth
                ? NSColor.taskInk.withAlphaComponent(0.85)
                : NSColor.taskMuted.withAlphaComponent(0.35)
        }

        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        trackingAreaRef = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        guard !isSelected else { return }
        isHovering = true
        layer?.backgroundColor = NSColor.taskInk.withAlphaComponent(0.06).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        guard !isSelected else { return }
        isHovering = false
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func mouseDown(with event: NSEvent) {
        onClick?(date)
    }
}

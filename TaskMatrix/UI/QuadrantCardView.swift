import Cocoa

/// Callbacks a task list needs, bundled so they thread through in one piece.
struct TaskListActions {
    let toggleCompleted: (String, Bool) -> Void
    let edit: (String) -> Void
    let move: (String, Quadrant) -> Void
    let delete: (String) -> Void
    let select: (String) -> Void
    let setDueDate: (String, Date?) -> Void
    let addSubtask: (String) -> Void
    let toggleSubtask: (String, String, Bool) -> Void
    let editSubtask: (String, String) -> Void
    let deleteSubtask: (String, String) -> Void
    let toggleExpanded: (String) -> Void
}

/// One quadrant of the matrix: tinted card, header with add button and
/// open-task count, scrollable task list, and drag & drop target.
final class QuadrantCardView: NSView {
    /// (droppedTaskID, beforeTaskID) — beforeTaskID is the open task the drop
    /// landed above, or nil to append to the end of the list.
    var onTaskDropped: ((String, String?) -> Void)?
    var onAddRequested: (() -> Void)?

    private let listStack = NSStackView()
    private let emptyStateLabel = NSTextField(labelWithString: "No tasks — drag one here")
    private let countLabel = NSTextField(labelWithString: "0")

    /// Open task rows in visual order, for hit-testing drop positions.
    private var openRows: [(id: String, view: NSView)] = []

    private let quadrant: Quadrant

    init(quadrant: Quadrant) {
        self.quadrant = quadrant
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupUI()
        registerForDraggedTypes([.taskID])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard sender.draggingPasteboard.availableType(from: [.taskID]) != nil else { return [] }
        setDropHighlight(true)
        return .move
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        setDropHighlight(false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        setDropHighlight(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        setDropHighlight(false)
        guard let taskID = sender.draggingPasteboard.string(forType: .taskID) else { return false }
        let beforeID = beforeTaskID(forDropAt: sender.draggingLocation, dragging: taskID)
        onTaskDropped?(taskID, beforeID)
        return true
    }

    /// Finds the open task the drop landed above. Window base coordinates are
    /// always y-up, so the first row (top → bottom) whose center is below the
    /// drop point is the insertion target; nil means append at the end.
    private func beforeTaskID(forDropAt windowPoint: NSPoint, dragging draggedID: String) -> String? {
        for row in openRows where row.id != draggedID {
            let rowMidY = row.view.convert(NSPoint(x: 0, y: row.view.bounds.midY), to: nil).y
            if windowPoint.y > rowMidY {
                return row.id
            }
        }
        return nil
    }

    func render(
        tasks: [TaskItem],
        selectedTaskID: String?,
        collapsedTaskIDs: Set<String>,
        actions: TaskListActions
    ) {
        listStack.arrangedSubviews.forEach { subview in
            listStack.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        openRows.removeAll()

        let openCount = tasks.filter { !$0.isCompleted }.count
        emptyStateLabel.isHidden = !tasks.isEmpty
        countLabel.stringValue = "\(openCount)"

        let sortedTasks = tasks.sorted { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted {
                return !lhs.isCompleted
            }
            // Within the same completion state, sort by explicit order first,
            // then by creation time as a fallback.
            if let lOrder = lhs.order, let rOrder = rhs.order {
                return lOrder < rOrder
            }
            if lhs.order != nil {
                return true
            }
            if rhs.order != nil {
                return false
            }
            return lhs.createdAt < rhs.createdAt
        }

        for task in sortedTasks {
            let row = TaskRowView(
                task: task,
                isSelected: task.id == selectedTaskID,
                isExpanded: !collapsedTaskIDs.contains(task.id)
            )
            if !task.isCompleted {
                openRows.append((id: task.id, view: row))
            }
            row.onToggleCompleted = { isCompleted in
                actions.toggleCompleted(task.id, isCompleted)
            }
            row.onEditRequested = {
                actions.edit(task.id)
            }
            row.onMoveRequested = { destination in
                actions.move(task.id, destination)
            }
            row.onDeleteRequested = {
                actions.delete(task.id)
            }
            row.onSelectRequested = {
                actions.select(task.id)
            }
            row.onSetDueDate = { dueDate in
                actions.setDueDate(task.id, dueDate)
            }
            row.onAddSubtaskRequested = {
                actions.addSubtask(task.id)
            }
            row.onToggleSubtask = { subtaskID, isCompleted in
                actions.toggleSubtask(task.id, subtaskID, isCompleted)
            }
            row.onEditSubtask = { subtaskID in
                actions.editSubtask(task.id, subtaskID)
            }
            row.onDeleteSubtask = { subtaskID in
                actions.deleteSubtask(task.id, subtaskID)
            }
            row.onToggleExpanded = {
                actions.toggleExpanded(task.id)
            }
            listStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: listStack.widthAnchor).isActive = true
        }
    }

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.backgroundColor = quadrant.surfaceColor.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.taskRing.cgColor

        let dot = NSView()
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.wantsLayer = true
        dot.layer?.backgroundColor = quadrant.accentColor.cgColor
        dot.layer?.cornerRadius = 5

        let strategyLabel = NSTextField(labelWithString: quadrant.strategy)
        strategyLabel.translatesAutoresizingMaskIntoConstraints = false
        strategyLabel.font = .systemFont(ofSize: 17, weight: .bold)
        strategyLabel.textColor = NSColor.taskInk

        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .bold)
        countLabel.textColor = NSColor.taskMuted
        countLabel.alignment = .center

        let countBadge = NSView()
        countBadge.translatesAutoresizingMaskIntoConstraints = false
        countBadge.wantsLayer = true
        countBadge.layer?.cornerRadius = 10
        countBadge.layer?.backgroundColor = NSColor.taskInk.withAlphaComponent(0.06).cgColor
        countBadge.addSubview(countLabel)

        let headerSpacer = NSView()
        headerSpacer.translatesAutoresizingMaskIntoConstraints = false
        headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        headerSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let addButton = NSButton(title: "", target: self, action: #selector(handleAddButton(_:)))
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.isBordered = false
        addButton.wantsLayer = true
        addButton.layer?.cornerRadius = 11
        addButton.layer?.backgroundColor = quadrant.accentColor.withAlphaComponent(0.22).cgColor
        addButton.attributedTitle = NSAttributedString(
            string: "+",
            attributes: [
                .font: NSFont.systemFont(ofSize: 15, weight: .bold),
                .foregroundColor: NSColor.taskInk.withAlphaComponent(0.75)
            ]
        )
        addButton.toolTip = "Add task to \(quadrant.strategy)"

        let headerRow = NSStackView(views: [dot, strategyLabel, headerSpacer, countBadge, addButton])
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 8

        let subtitleLabel = NSTextField(labelWithString: "")
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        let subtitleText = NSMutableAttributedString(string: quadrant.subtitle)
        subtitleText.addAttributes(
            [
                .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: NSColor.taskMuted,
                .kern: 0.7
            ],
            range: NSRange(location: 0, length: subtitleText.length)
        )
        subtitleLabel.attributedStringValue = subtitleText

        let separator = NSView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.taskRing.cgColor

        listStack.translatesAutoresizingMaskIntoConstraints = false
        listStack.orientation = .vertical
        listStack.alignment = .leading
        listStack.spacing = 6

        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateLabel.font = .systemFont(ofSize: 12, weight: .medium)
        emptyStateLabel.textColor = NSColor.taskMuted.withAlphaComponent(0.75)

        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(listStack)
        contentView.addSubview(emptyStateLabel)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = contentView

        addSubview(headerRow)
        addSubview(subtitleLabel)
        addSubview(separator)
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 10),
            dot.heightAnchor.constraint(equalToConstant: 10),

            addButton.widthAnchor.constraint(equalToConstant: 22),
            addButton.heightAnchor.constraint(equalToConstant: 22),

            countLabel.leadingAnchor.constraint(equalTo: countBadge.leadingAnchor, constant: 9),
            countLabel.trailingAnchor.constraint(equalTo: countBadge.trailingAnchor, constant: -9),
            countLabel.topAnchor.constraint(equalTo: countBadge.topAnchor, constant: 3),
            countLabel.bottomAnchor.constraint(equalTo: countBadge.bottomAnchor, constant: -3),
            countLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 12),

            headerRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            headerRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            headerRow.topAnchor.constraint(equalTo: topAnchor, constant: 14),

            subtitleLabel.leadingAnchor.constraint(equalTo: headerRow.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 2),

            separator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            separator.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 10),
            separator.heightAnchor.constraint(equalToConstant: 1),

            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            scrollView.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 10),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

            listStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            listStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            listStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            listStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -4),

            emptyStateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            emptyStateLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4)
        ])
    }

    @objc
    private func handleAddButton(_ sender: NSButton) {
        onAddRequested?()
    }

    private func setDropHighlight(_ isActive: Bool) {
        layer?.borderWidth = isActive ? 2 : 1
        layer?.borderColor = (isActive ? quadrant.accentColor : NSColor.taskRing).cgColor
        layer?.backgroundColor = (isActive
            ? quadrant.accentColor.withAlphaComponent(0.16)
            : quadrant.surfaceColor).cgColor
    }
}

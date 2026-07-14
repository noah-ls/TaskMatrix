import Cocoa

/// One task card inside a quadrant: checkbox, title, and — when subtasks
/// exist — a progress badge, a chevron, and the expandable subtask list.
final class TaskRowView: NSView {
    var onToggleCompleted: ((Bool) -> Void)?
    var onEditRequested: (() -> Void)?
    var onMoveRequested: ((Quadrant) -> Void)?
    var onDeleteRequested: (() -> Void)?
    var onSelectRequested: (() -> Void)?
    var onAddSubtaskRequested: (() -> Void)?
    var onToggleSubtask: ((String, Bool) -> Void)?
    var onEditSubtask: ((String) -> Void)?
    var onDeleteSubtask: ((String) -> Void)?
    var onToggleExpanded: (() -> Void)?

    private let task: TaskItem
    private let isSelected: Bool
    private var isExpanded: Bool
    private var isHovering = false
    private var trackingAreaRef: NSTrackingArea?
    private var subtaskStack: NSStackView?
    private var chevronButton: NSButton?

    private let titleLabel = NSTextField(labelWithString: "")
    private let progressLabel = NSTextField(labelWithString: "")
    private lazy var completeCheckbox: NSButton = {
        let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(handleCheckboxChange(_:)))
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        checkbox.setButtonType(.switch)
        checkbox.contentTintColor = NSColor.taskAccentText
        checkbox.controlSize = .regular
        return checkbox
    }()

    init(task: TaskItem, isSelected: Bool, isExpanded: Bool) {
        self.task = task
        self.isSelected = isSelected
        self.isExpanded = isExpanded
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupUI()
        updateAppearance()
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
        isHovering = true
        refreshContainerStyle()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovering = false
        refreshContainerStyle()
    }

    override func mouseDown(with event: NSEvent) {
        // Selection on the first click, edit on the second — branching on
        // clickCount responds instantly, unlike a double-click gesture
        // recognizer, which delays every single click by the double-click
        // interval while it waits for a possible second click.
        onSelectRequested?()
        if event.clickCount == 2 {
            onEditRequested?()
        }
        // No super call: the click must not bubble to the background,
        // which would immediately clear the selection it just made.
    }

    override func mouseDragged(with event: NSEvent) {
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(task.id, forType: .taskID)

        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        draggingItem.setDraggingFrame(bounds, contents: draggingImage())

        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    private func draggingImage() -> NSImage {
        guard let rep = bitmapImageRepForCachingDisplay(in: bounds) else {
            return NSImage(size: bounds.size)
        }
        cacheDisplay(in: bounds, to: rep)

        let image = NSImage(size: bounds.size)
        image.addRepresentation(rep)
        return image
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu(title: "Task")

        let addSubtaskItem = NSMenuItem(title: "Add Subtask…", action: #selector(handleAddSubtask(_:)), keyEquivalent: "")
        addSubtaskItem.target = self
        menu.addItem(addSubtaskItem)
        menu.addItem(.separator())

        let moveMenuItem = NSMenuItem(title: "Move to", action: nil, keyEquivalent: "")
        let moveMenu = NSMenu(title: "Move to")

        for quadrant in Quadrant.allCases where quadrant != task.quadrant {
            let item = NSMenuItem(
                title: "\(quadrant.strategy) — \(quadrant.title)",
                action: #selector(handleMoveToQuadrant(_:)),
                keyEquivalent: ""
            )
            item.representedObject = quadrant.rawValue
            item.target = self
            moveMenu.addItem(item)
        }

        moveMenuItem.submenu = moveMenu
        menu.addItem(moveMenuItem)
        menu.addItem(.separator())

        let deleteItem = NSMenuItem(title: "Delete", action: #selector(handleDelete(_:)), keyEquivalent: "")
        deleteItem.target = self
        menu.addItem(deleteItem)

        return menu
    }

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.borderWidth = 1

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1

        let headerSpacer = NSView()
        headerSpacer.translatesAutoresizingMaskIntoConstraints = false
        headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        headerSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        var headerViews: [NSView] = [completeCheckbox, titleLabel, headerSpacer]

        if !task.subtasks.isEmpty {
            progressLabel.translatesAutoresizingMaskIntoConstraints = false
            progressLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .bold)
            progressLabel.textColor = NSColor.taskMuted
            headerViews.append(progressLabel)

            // Fixed 24x24 button so the header never reflows on toggle;
            // the symbol swap is safe inside that constant footprint.
            let chevron = NSButton(title: "", target: self, action: #selector(handleToggleExpanded(_:)))
            chevron.translatesAutoresizingMaskIntoConstraints = false
            chevron.isBordered = false
            chevron.imagePosition = .imageOnly
            chevron.image = Self.chevronImage(expanded: isExpanded)
            chevron.contentTintColor = NSColor.taskMuted
            chevronButton = chevron
            headerViews.append(chevron)
        }

        let headerRow = NSStackView(views: headerViews)
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 9

        let contentStack = NSStackView(views: [headerRow])
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 6

        addSubview(contentStack)

        NSLayoutConstraint.activate([
            completeCheckbox.widthAnchor.constraint(equalToConstant: 18),
            completeCheckbox.heightAnchor.constraint(equalToConstant: 18),

            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 11),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -11),
            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: 9),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -9),

            headerRow.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            headerRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 22)
        ])

        if let chevronButton {
            NSLayoutConstraint.activate([
                chevronButton.widthAnchor.constraint(equalToConstant: 24),
                chevronButton.heightAnchor.constraint(equalToConstant: 24)
            ])
        }

        if !task.subtasks.isEmpty {
            let stack = NSStackView()
            stack.translatesAutoresizingMaskIntoConstraints = false
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.spacing = 3

            for subtask in task.subtasks {
                let row = SubtaskRowView(subtask: subtask)
                row.onToggle = { [weak self] isCompleted in
                    self?.onToggleSubtask?(subtask.id, isCompleted)
                }
                row.onEditRequested = { [weak self] in
                    self?.onEditSubtask?(subtask.id)
                }
                row.onDeleteRequested = { [weak self] in
                    self?.onDeleteSubtask?(subtask.id)
                }
                stack.addArrangedSubview(row)
                row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            }

            stack.isHidden = !isExpanded
            contentStack.addArrangedSubview(stack)
            stack.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
            subtaskStack = stack
        }
    }

    private func updateAppearance() {
        completeCheckbox.state = task.isCompleted ? .on : .off

        if !task.subtasks.isEmpty {
            let completedCount = task.subtasks.filter(\.isCompleted).count
            progressLabel.stringValue = "\(completedCount)/\(task.subtasks.count)"
        }

        if task.isCompleted {
            titleLabel.attributedStringValue = NSAttributedString(
                string: task.title,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                    .foregroundColor: NSColor.taskMuted,
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .strikethroughColor: NSColor.taskMuted
                ]
            )
            alphaValue = 0.6
        } else {
            titleLabel.attributedStringValue = NSAttributedString(
                string: task.title,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                    .foregroundColor: NSColor.taskInk
                ]
            )
            alphaValue = 1
        }

        refreshContainerStyle()
    }

    private func refreshContainerStyle() {
        guard let layer else { return }

        let accent = task.quadrant.accentColor

        if isSelected {
            layer.borderWidth = 2
            layer.borderColor = accent.cgColor
            layer.backgroundColor = NSColor.taskSurface.cgColor
            return
        }

        layer.borderWidth = 1
        layer.backgroundColor = NSColor.taskSurface.cgColor
        layer.borderColor = (isHovering ? accent.withAlphaComponent(0.45) : NSColor.taskRing).cgColor
    }

    private static func chevronImage(expanded: Bool) -> NSImage? {
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        return NSImage(
            systemSymbolName: expanded ? "chevron.down" : "chevron.right",
            accessibilityDescription: expanded ? "Collapse subtasks" : "Expand subtasks"
        )?.withSymbolConfiguration(symbolConfig)
    }

    @objc
    private func handleCheckboxChange(_ sender: NSButton) {
        onToggleCompleted?(sender.state == .on)
    }

    @objc
    private func handleToggleExpanded(_ sender: NSButton) {
        isExpanded.toggle()
        onToggleExpanded?()

        chevronButton?.image = Self.chevronImage(expanded: isExpanded)

        NSAnimationContext.runAnimationGroup { [weak self] context in
            guard let self else { return }
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true

            self.subtaskStack?.animator().isHidden = !self.isExpanded
            self.window?.contentView?.layoutSubtreeIfNeeded()
        }
    }

    @objc
    private func handleAddSubtask(_ sender: NSMenuItem) {
        onAddSubtaskRequested?()
    }

    @objc
    private func handleMoveToQuadrant(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let destination = Quadrant(rawValue: rawValue) else {
            return
        }

        onMoveRequested?(destination)
    }

    @objc
    private func handleDelete(_ sender: NSMenuItem) {
        onDeleteRequested?()
    }
}

extension TaskRowView: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .withinApplication ? .move : []
    }
}

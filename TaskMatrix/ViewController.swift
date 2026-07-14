import Cocoa

private extension NSPasteboard.PasteboardType {
    static let taskID = NSPasteboard.PasteboardType("com.taskmatrix.task-id")
}

private enum Quadrant: String, CaseIterable, Codable {
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
}

private struct TaskItem: Codable, Equatable {
    let id: String
    var title: String
    var quadrant: Quadrant
    var isCompleted: Bool
    let createdAt: Date
}

private final class TaskStore {
    var onChange: (([TaskItem]) -> Void)?

    private(set) var tasks: [TaskItem] = []
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        load()
    }

    func addTask(title: String, quadrant: Quadrant) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        tasks.append(
            TaskItem(
                id: UUID().uuidString,
                title: trimmedTitle,
                quadrant: quadrant,
                isCompleted: false,
                createdAt: Date()
            )
        )
        persistAndNotify()
    }

    func updateTitle(id: String, newTitle: String) {
        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }

        tasks[index].title = trimmedTitle
        persistAndNotify()
    }

    func moveTask(id: String, to quadrant: Quadrant) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }

        tasks[index].quadrant = quadrant
        persistAndNotify()
    }

    func setTaskCompleted(id: String, isCompleted: Bool) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }

        tasks[index].isCompleted = isCompleted
        persistAndNotify()
    }

    func deleteTask(id: String) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }

        tasks.remove(at: index)
        persistAndNotify()
    }

    func task(id: String) -> TaskItem? {
        tasks.first(where: { $0.id == id })
    }

    private func persistAndNotify() {
        save()
        onChange?(tasks)
    }

    private func load() {
        let url = storageURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            onChange?(tasks)
            return
        }

        do {
            let data = try Data(contentsOf: url)
            tasks = try decoder.decode([TaskItem].self, from: data)
        } catch {
            NSLog("[TaskStore] Failed loading tasks: \(error.localizedDescription)")
            tasks = []
        }

        onChange?(tasks)
    }

    private func save() {
        let url = storageURL()

        do {
            let data = try encoder.encode(tasks)
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("[TaskStore] Failed saving tasks: \(error.localizedDescription)")
        }
    }

    private func storageURL() -> URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let directory = appSupport.appendingPathComponent("TaskMatrix", isDirectory: true)

        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory.appendingPathComponent("tasks.json", isDirectory: false)
    }
}

/// Lime pill CTA in the Wise style: dark-green label, grows on hover, compresses on click.
private final class PillButton: NSButton {
    private var trackingAreaRef: NSTrackingArea?

    init(title: String, target: AnyObject?, action: Selector?) {
        super.init(frame: .zero)
        self.target = target
        self.action = action

        translatesAutoresizingMaskIntoConstraints = false
        isBordered = false
        wantsLayer = true
        layer?.backgroundColor = NSColor.taskAccent.cgColor
        layer?.cornerRadius = 18

        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 14, weight: .bold),
                .foregroundColor: NSColor.taskAccentText
            ]
        )

        heightAnchor.constraint(equalToConstant: 36).isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        var size = super.intrinsicContentSize
        size.width += 36
        return size
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
        animateScale(to: 1.05)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        animateScale(to: 1)
    }

    override func mouseDown(with event: NSEvent) {
        animateScale(to: 0.95)
        super.mouseDown(with: event)

        let location = convert(event.locationInWindow, from: nil)
        animateScale(to: bounds.contains(location) ? 1.05 : 1)
    }

    private func animateScale(to scale: CGFloat) {
        guard let layer else { return }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        layer.position = center
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.transform = CATransform3DMakeScale(scale, scale, 1)
    }
}

private final class TaskRowView: NSView {
    var onToggleCompleted: ((Bool) -> Void)?
    var onEditRequested: (() -> Void)?
    var onMoveRequested: ((Quadrant) -> Void)?
    var onDeleteRequested: (() -> Void)?

    private let task: TaskItem
    private var isHovering = false
    private var trackingAreaRef: NSTrackingArea?

    private let titleLabel = NSTextField(labelWithString: "")
    private lazy var completeCheckbox: NSButton = {
        let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(handleCheckboxChange(_:)))
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        checkbox.setButtonType(.switch)
        checkbox.contentTintColor = NSColor.taskAccentText
        checkbox.controlSize = .small
        return checkbox
    }()

    init(task: TaskItem) {
        self.task = task
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

        let rowStack = NSStackView(views: [completeCheckbox, titleLabel])
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.spacing = 9

        addSubview(rowStack)

        NSLayoutConstraint.activate([
            completeCheckbox.widthAnchor.constraint(equalToConstant: 16),
            completeCheckbox.heightAnchor.constraint(equalToConstant: 16),

            rowStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 11),
            rowStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -11),
            rowStack.topAnchor.constraint(equalTo: topAnchor, constant: 9),
            rowStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -9),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 38)
        ])

        let doubleClickRecognizer = NSClickGestureRecognizer(target: self, action: #selector(handleDoubleClick(_:)))
        doubleClickRecognizer.numberOfClicksRequired = 2
        addGestureRecognizer(doubleClickRecognizer)
    }

    private func updateAppearance() {
        completeCheckbox.state = task.isCompleted ? .on : .off

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

        let backgroundColor: NSColor
        if task.isCompleted {
            backgroundColor = .taskSurface
        } else {
            backgroundColor = isHovering ? .taskSurfaceHover : .taskSurface
        }

        layer.backgroundColor = backgroundColor.cgColor
        layer.borderColor = (isHovering ? NSColor.taskAccent.withAlphaComponent(0.55) : NSColor.taskRing).cgColor
    }

    @objc
    private func handleCheckboxChange(_ sender: NSButton) {
        onToggleCompleted?(sender.state == .on)
    }

    @objc
    private func handleDoubleClick(_ recognizer: NSClickGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        onEditRequested?()
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

private final class QuadrantCardView: NSView {
    var onTaskDropped: ((String) -> Void)?

    private let listStack = NSStackView()
    private let emptyStateLabel = NSTextField(labelWithString: "No tasks — drag one here")
    private let countLabel = NSTextField(labelWithString: "0")

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
        onTaskDropped?(taskID)
        return true
    }

    func render(
        tasks: [TaskItem],
        onToggleCompleted: @escaping (String, Bool) -> Void,
        onEditRequested: @escaping (String) -> Void,
        onMoveRequested: @escaping (String, Quadrant) -> Void,
        onDeleteRequested: @escaping (String) -> Void
    ) {
        listStack.arrangedSubviews.forEach { subview in
            listStack.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        let openCount = tasks.filter { !$0.isCompleted }.count
        emptyStateLabel.isHidden = !tasks.isEmpty
        countLabel.stringValue = "\(openCount)"

        let sortedTasks = tasks.sorted { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted {
                return !lhs.isCompleted
            }
            return lhs.createdAt < rhs.createdAt
        }

        for task in sortedTasks {
            let row = TaskRowView(task: task)
            row.onToggleCompleted = { isCompleted in
                onToggleCompleted(task.id, isCompleted)
            }
            row.onEditRequested = {
                onEditRequested(task.id)
            }
            row.onMoveRequested = { destination in
                onMoveRequested(task.id, destination)
            }
            row.onDeleteRequested = {
                onDeleteRequested(task.id)
            }
            listStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: listStack.widthAnchor).isActive = true
        }
    }

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.backgroundColor = NSColor.taskCard.cgColor
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

        let headerRow = NSStackView(views: [dot, strategyLabel, headerSpacer, countBadge])
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 8

        let subtitleLabel = NSTextField(labelWithString: quadrant.subtitle)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        subtitleLabel.textColor = NSColor.taskMuted

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

    private func setDropHighlight(_ isActive: Bool) {
        layer?.borderWidth = isActive ? 2 : 1
        layer?.borderColor = (isActive ? quadrant.accentColor : NSColor.taskRing).cgColor
        layer?.backgroundColor = (isActive
            ? quadrant.accentColor.withAlphaComponent(0.06)
            : NSColor.taskCard).cgColor
    }
}

final class ViewController: NSViewController {
    private let store = TaskStore()
    private var quadrantViews: [Quadrant: QuadrantCardView] = [:]
    private var didInstallCommandN = false

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1080, height: 720))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupRootUI()
        bindStore()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        installCommandNShortcutIfNeeded()

        view.window?.title = "Task Matrix"
        view.window?.minSize = NSSize(width: 760, height: 560)
    }

    private func setupRootUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.taskCanvas.cgColor

        // Header — one compact line: title on the left, actions on the right.
        let titleLabel = NSTextField(labelWithString: "")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.attributedStringValue = NSAttributedString(
            string: "Task Matrix",
            attributes: [
                .font: NSFont.systemFont(ofSize: 22, weight: .black),
                .foregroundColor: NSColor.taskInk,
                .kern: -0.4
            ]
        )

        let subtitleLabel = NSTextField(labelWithString: "Decide what to do next — not just list tasks.")
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        subtitleLabel.textColor = NSColor.taskMuted

        let titleStack = NSStackView(views: [titleLabel, subtitleLabel])
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 1

        let shortcutHint = NSTextField(labelWithString: "⌘N")
        shortcutHint.translatesAutoresizingMaskIntoConstraints = false
        shortcutHint.font = .systemFont(ofSize: 12, weight: .semibold)
        shortcutHint.textColor = NSColor.taskMuted

        let addTaskButton = PillButton(title: "+ New Task", target: self, action: #selector(handleAddTaskAction(_:)))

        let headerSpacer = NSView()
        headerSpacer.translatesAutoresizingMaskIntoConstraints = false
        headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        headerSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let headerRow = NSStackView(views: [titleStack, headerSpacer, shortcutHint, addTaskButton])
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 12

        // Matrix — a true 2x2 grid; rows pinned to full width so columns align.
        let topRow = NSStackView()
        topRow.translatesAutoresizingMaskIntoConstraints = false
        topRow.orientation = .horizontal
        topRow.distribution = .fillEqually
        topRow.spacing = 14

        let bottomRow = NSStackView()
        bottomRow.translatesAutoresizingMaskIntoConstraints = false
        bottomRow.orientation = .horizontal
        bottomRow.distribution = .fillEqually
        bottomRow.spacing = 14

        for quadrant in [Quadrant.q1, .q2] {
            topRow.addArrangedSubview(makeQuadrantCard(for: quadrant))
        }

        for quadrant in [Quadrant.q3, .q4] {
            bottomRow.addArrangedSubview(makeQuadrantCard(for: quadrant))
        }

        let matrixStack = NSStackView(views: [topRow, bottomRow])
        matrixStack.translatesAutoresizingMaskIntoConstraints = false
        matrixStack.orientation = .vertical
        matrixStack.distribution = .fillEqually
        matrixStack.alignment = .leading
        matrixStack.spacing = 14

        view.addSubview(headerRow)
        view.addSubview(matrixStack)

        NSLayoutConstraint.activate([
            headerRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            headerRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            headerRow.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),

            matrixStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            matrixStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            matrixStack.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 16),
            matrixStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),

            topRow.widthAnchor.constraint(equalTo: matrixStack.widthAnchor),
            bottomRow.widthAnchor.constraint(equalTo: matrixStack.widthAnchor)
        ])
    }

    private func makeQuadrantCard(for quadrant: Quadrant) -> QuadrantCardView {
        let card = QuadrantCardView(quadrant: quadrant)
        card.onTaskDropped = { [weak self] taskID in
            self?.store.moveTask(id: taskID, to: quadrant)
        }
        quadrantViews[quadrant] = card
        return card
    }

    private func bindStore() {
        store.onChange = { [weak self] tasks in
            self?.render(tasks: tasks)
        }

        render(tasks: store.tasks)
    }

    private func render(tasks: [TaskItem]) {
        for quadrant in Quadrant.allCases {
            let quadrantTasks = tasks.filter { $0.quadrant == quadrant }
            quadrantViews[quadrant]?.render(
                tasks: quadrantTasks,
                onToggleCompleted: { [weak self] taskID, isCompleted in
                    self?.store.setTaskCompleted(id: taskID, isCompleted: isCompleted)
                },
                onEditRequested: { [weak self] taskID in
                    self?.presentEditTaskDialog(taskID: taskID)
                },
                onMoveRequested: { [weak self] taskID, destination in
                    self?.store.moveTask(id: taskID, to: destination)
                },
                onDeleteRequested: { [weak self] taskID in
                    self?.store.deleteTask(id: taskID)
                }
            )
        }
    }

    private func installCommandNShortcutIfNeeded() {
        guard !didInstallCommandN else { return }
        guard let mainMenu = NSApp.mainMenu,
              let fileMenuItem = mainMenu.item(withTitle: "File"),
              let fileMenu = fileMenuItem.submenu,
              let newItem = fileMenu.items.first(where: {
                  $0.keyEquivalent.lowercased() == "n" && $0.keyEquivalentModifierMask.contains(.command)
              }) else {
            return
        }

        newItem.title = "New Task"
        newItem.target = self
        newItem.action = #selector(handleAddTaskAction(_:))
        didInstallCommandN = true
    }

    @objc
    private func handleAddTaskAction(_ sender: Any?) {
        presentAddTaskDialog()
    }

    private func presentAddTaskDialog() {
        let alert = NSAlert()
        alert.messageText = "New Task"
        alert.informativeText = "Add a title and choose a quadrant."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let titleLabel = NSTextField(labelWithString: "Title")
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)

        let titleField = NSTextField(string: "")
        titleField.placeholderString = "Enter task title"

        let quadrantLabel = NSTextField(labelWithString: "Quadrant")
        quadrantLabel.font = .systemFont(ofSize: 12, weight: .semibold)

        let quadrantPicker = NSPopUpButton()
        Quadrant.allCases.forEach { quadrant in
            quadrantPicker.addItem(withTitle: "\(quadrant.strategy) — \(quadrant.title)")
            quadrantPicker.lastItem?.representedObject = quadrant.rawValue
        }

        let accessory = NSStackView(views: [titleLabel, titleField, quadrantLabel, quadrantPicker])
        accessory.orientation = .vertical
        accessory.alignment = .leading
        accessory.spacing = 8
        accessory.translatesAutoresizingMaskIntoConstraints = false

        titleField.translatesAutoresizingMaskIntoConstraints = false
        quadrantPicker.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleField.widthAnchor.constraint(equalToConstant: 320),
            quadrantPicker.widthAnchor.constraint(equalTo: titleField.widthAnchor)
        ])

        alert.accessoryView = accessory
        alert.window.initialFirstResponder = titleField

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let trimmedTitle = titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            showValidationError(message: "Task title is required.")
            return
        }

        guard let rawValue = quadrantPicker.selectedItem?.representedObject as? String,
              let quadrant = Quadrant(rawValue: rawValue) else {
            showValidationError(message: "Please choose a quadrant.")
            return
        }

        store.addTask(title: trimmedTitle, quadrant: quadrant)
    }

    private func presentEditTaskDialog(taskID: String) {
        guard let task = store.task(id: taskID) else { return }

        let alert = NSAlert()
        alert.messageText = "Edit Task"
        alert.informativeText = "Update the task title."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let titleField = NSTextField(string: task.title)
        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.widthAnchor.constraint(equalToConstant: 320).isActive = true
        alert.accessoryView = titleField
        alert.window.initialFirstResponder = titleField

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let trimmedTitle = titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            showValidationError(message: "Task title is required.")
            return
        }

        store.updateTitle(id: taskID, newTitle: trimmedTitle)
    }

    private func showValidationError(message: String) {
        let alert = NSAlert()
        alert.messageText = "Validation Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

private extension NSColor {
    static let taskCanvas = NSColor(red: 0.957, green: 0.961, blue: 0.945, alpha: 1)
    static let taskCard = NSColor.white

    static let taskInk = NSColor(red: 0.055, green: 0.059, blue: 0.047, alpha: 1)
    static let taskMuted = NSColor(red: 0.42, green: 0.45, blue: 0.41, alpha: 1)

    static let taskAccent = NSColor(red: 0.624, green: 0.909, blue: 0.439, alpha: 1)
    static let taskAccentText = NSColor(red: 0.086, green: 0.200, blue: 0.0, alpha: 1)

    static let taskRing = NSColor(red: 0.055, green: 0.059, blue: 0.047, alpha: 0.10)
    static let taskSurface = NSColor(red: 0.975, green: 0.978, blue: 0.968, alpha: 1)
    static let taskSurfaceHover = NSColor(red: 0.960, green: 0.982, blue: 0.930, alpha: 1)
}

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

    var shortLabel: String {
        rawValue.uppercased()
    }

    var strategy: String {
        switch self {
        case .q1:
            return "DO FIRST"
        case .q2:
            return "SCHEDULE"
        case .q3:
            return "DELEGATE"
        case .q4:
            return "ELIMINATE"
        }
    }

    var surfaceColor: NSColor {
        switch self {
        case .q1:
            return .taskCardWarm
        case .q2:
            return .taskCardFresh
        case .q3:
            return .taskCardMist
        case .q4:
            return .taskCardLight
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

private final class HoverScaleButton: NSButton {
    private var trackingAreaRef: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
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

    private func commonInit() {
        wantsLayer = true
        isBordered = false
    }

    private func animateScale(to scale: CGFloat) {
        guard let layer else { return }
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
            let item = NSMenuItem(title: quadrant.title, action: #selector(handleMoveToQuadrant(_:)), keyEquivalent: "")
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
        layer?.cornerRadius = 16
        layer?.borderWidth = 1

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1

        let rowStack = NSStackView(views: [completeCheckbox, titleLabel])
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.spacing = 10

        addSubview(rowStack)

        NSLayoutConstraint.activate([
            completeCheckbox.widthAnchor.constraint(equalToConstant: 18),
            completeCheckbox.heightAnchor.constraint(equalToConstant: 18),

            rowStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            rowStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            rowStack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            rowStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])

        let doubleClickRecognizer = NSClickGestureRecognizer(target: self, action: #selector(handleDoubleClick(_:)))
        doubleClickRecognizer.numberOfClicksRequired = 2
        addGestureRecognizer(doubleClickRecognizer)
    }

    private func updateAppearance() {
        completeCheckbox.state = task.isCompleted ? .on : .off
        titleLabel.stringValue = task.title
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)

        if task.isCompleted {
            alphaValue = 0.55
            titleLabel.textColor = NSColor.taskMuted
        } else {
            alphaValue = 1
            titleLabel.textColor = NSColor.taskInk
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
        layer.borderColor = (isHovering ? NSColor.taskAccent.withAlphaComponent(0.45) : NSColor.taskRing).cgColor
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
    private let emptyStateLabel = NSTextField(labelWithString: "No tasks yet")
    private let taskCountLabel = NSTextField(labelWithString: "0 Tasks")

    private let quadrant: Quadrant

    init(quadrant: Quadrant) {
        self.quadrant = quadrant
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupUI()
        registerForDraggedTypes([.taskID])
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

    private func setDropHighlight(_ isActive: Bool) {
        layer?.borderWidth = isActive ? 2 : 1
        layer?.borderColor = (isActive ? NSColor.taskAccent : NSColor.taskRing).cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

        emptyStateLabel.isHidden = !tasks.isEmpty
        taskCountLabel.stringValue = "\(tasks.count) \(tasks.count == 1 ? "Task" : "Tasks")"

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
        layer?.cornerRadius = 34
        layer?.backgroundColor = quadrant.surfaceColor.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.taskRing.cgColor

        let accentLine = NSView()
        accentLine.translatesAutoresizingMaskIntoConstraints = false
        accentLine.wantsLayer = true
        accentLine.layer?.backgroundColor = NSColor.taskAccent.withAlphaComponent(0.85).cgColor
        accentLine.layer?.cornerRadius = 2

        let badgeText = NSTextField(labelWithString: quadrant.shortLabel)
        badgeText.translatesAutoresizingMaskIntoConstraints = false
        badgeText.font = .systemFont(ofSize: 11, weight: .bold)
        badgeText.textColor = NSColor.taskAccentText

        let badgeView = NSView()
        badgeView.translatesAutoresizingMaskIntoConstraints = false
        badgeView.wantsLayer = true
        badgeView.layer?.cornerRadius = 999
        badgeView.layer?.backgroundColor = NSColor.taskAccent.withAlphaComponent(0.34).cgColor
        badgeView.addSubview(badgeText)

        let titleLabel = NSTextField(labelWithString: quadrant.title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 19, weight: .black)
        titleLabel.textColor = NSColor.taskInk

        let strategyLabel = NSTextField(labelWithString: quadrant.strategy)
        strategyLabel.translatesAutoresizingMaskIntoConstraints = false
        strategyLabel.font = .systemFont(ofSize: 11, weight: .bold)
        strategyLabel.textColor = NSColor.taskMuted

        taskCountLabel.translatesAutoresizingMaskIntoConstraints = false
        taskCountLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        taskCountLabel.textColor = NSColor.taskMuted

        let headerSpacer = NSView()
        headerSpacer.translatesAutoresizingMaskIntoConstraints = false

        let titleRow = NSStackView(views: [badgeView, titleLabel, headerSpacer, taskCountLabel])
        titleRow.translatesAutoresizingMaskIntoConstraints = false
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 10

        headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        headerSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        listStack.translatesAutoresizingMaskIntoConstraints = false
        listStack.orientation = .vertical
        listStack.alignment = .leading
        listStack.spacing = 8

        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        emptyStateLabel.textColor = NSColor.taskMuted

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

        addSubview(accentLine)
        addSubview(titleRow)
        addSubview(strategyLabel)
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            accentLine.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            accentLine.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            accentLine.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            accentLine.heightAnchor.constraint(equalToConstant: 4),

            badgeText.leadingAnchor.constraint(equalTo: badgeView.leadingAnchor, constant: 10),
            badgeText.trailingAnchor.constraint(equalTo: badgeView.trailingAnchor, constant: -10),
            badgeText.topAnchor.constraint(equalTo: badgeView.topAnchor, constant: 5),
            badgeText.bottomAnchor.constraint(equalTo: badgeView.bottomAnchor, constant: -5),

            titleRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            titleRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            titleRow.topAnchor.constraint(equalTo: accentLine.bottomAnchor, constant: 14),

            strategyLabel.leadingAnchor.constraint(equalTo: titleRow.leadingAnchor),
            strategyLabel.topAnchor.constraint(equalTo: titleRow.bottomAnchor, constant: 4),

            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            scrollView.topAnchor.constraint(equalTo: strategyLabel.bottomAnchor, constant: 12),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

            listStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            listStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            listStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            listStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -6),

            emptyStateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            emptyStateLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8)
        ])
    }
}

final class ViewController: NSViewController {
    private let store = TaskStore()
    private var quadrantViews: [Quadrant: QuadrantCardView] = [:]
    private var didInstallCommandN = false

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1180, height: 820))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupRootUI()
        bindStore()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        installCommandNShortcutIfNeeded()
    }

    private func setupRootUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.taskCanvas.cgColor

        installDecorativeBackground()

        let eyebrowLabel = NSTextField(labelWithString: "EISENHOWER METHOD")
        eyebrowLabel.translatesAutoresizingMaskIntoConstraints = false
        eyebrowLabel.font = .systemFont(ofSize: 12, weight: .bold)
        eyebrowLabel.textColor = NSColor.taskAccentText

        let eyebrowCapsule = NSView()
        eyebrowCapsule.translatesAutoresizingMaskIntoConstraints = false
        eyebrowCapsule.wantsLayer = true
        eyebrowCapsule.layer?.cornerRadius = 999
        eyebrowCapsule.layer?.backgroundColor = NSColor.taskAccent.withAlphaComponent(0.34).cgColor
        eyebrowCapsule.addSubview(eyebrowLabel)

        let titleLabel = NSTextField(labelWithString: "")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.maximumNumberOfLines = 2
        titleLabel.lineBreakMode = .byWordWrapping

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = 0.86

        titleLabel.attributedStringValue = NSAttributedString(
            string: "TASK\nMATRIX",
            attributes: [
                .font: NSFont.systemFont(ofSize: 74, weight: .black),
                .foregroundColor: NSColor.taskInk,
                .paragraphStyle: paragraph,
                .kern: -1.2
            ]
        )

        let subtitleLabel = NSTextField(labelWithString: "Prioritize what matters. Move fast with zero clutter.")
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        subtitleLabel.textColor = NSColor.taskMuted

        let titleStack = NSStackView(views: [eyebrowCapsule, titleLabel, subtitleLabel])
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 8

        let addTaskButton = HoverScaleButton(title: "+ New Task", target: self, action: #selector(handleAddTaskAction(_:)))
        addTaskButton.translatesAutoresizingMaskIntoConstraints = false
        addTaskButton.bezelStyle = .regularSquare
        addTaskButton.layer?.cornerRadius = 999
        addTaskButton.layer?.backgroundColor = NSColor.taskAccent.cgColor
        addTaskButton.contentTintColor = NSColor.taskAccentText
        addTaskButton.font = .systemFont(ofSize: 15, weight: .bold)

        let shortcutHint = NSTextField(labelWithString: "⌘N Quick Create")
        shortcutHint.translatesAutoresizingMaskIntoConstraints = false
        shortcutHint.font = .systemFont(ofSize: 12, weight: .semibold)
        shortcutHint.textColor = NSColor.taskMuted

        let actionStack = NSStackView(views: [addTaskButton, shortcutHint])
        actionStack.translatesAutoresizingMaskIntoConstraints = false
        actionStack.orientation = .vertical
        actionStack.alignment = .trailing
        actionStack.spacing = 8

        let headerSpacer = NSView()
        headerSpacer.translatesAutoresizingMaskIntoConstraints = false

        let headerStack = NSStackView(views: [titleStack, headerSpacer, actionStack])
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.orientation = .horizontal
        headerStack.alignment = .top
        headerStack.spacing = 16

        headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        headerSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let matrixStack = NSStackView()
        matrixStack.translatesAutoresizingMaskIntoConstraints = false
        matrixStack.orientation = .vertical
        matrixStack.distribution = .fillEqually
        matrixStack.spacing = 18

        let topRow = NSStackView()
        topRow.orientation = .horizontal
        topRow.distribution = .fillEqually
        topRow.spacing = 18

        let bottomRow = NSStackView()
        bottomRow.orientation = .horizontal
        bottomRow.distribution = .fillEqually
        bottomRow.spacing = 18

        for quadrant in [Quadrant.q1, .q2] {
            let card = makeQuadrantCard(for: quadrant)
            topRow.addArrangedSubview(card)
        }

        for quadrant in [Quadrant.q3, .q4] {
            let card = makeQuadrantCard(for: quadrant)
            bottomRow.addArrangedSubview(card)
        }

        matrixStack.addArrangedSubview(topRow)
        matrixStack.addArrangedSubview(bottomRow)

        let matrixContainer = NSView()
        matrixContainer.translatesAutoresizingMaskIntoConstraints = false
        matrixContainer.wantsLayer = true
        matrixContainer.layer?.cornerRadius = 40
        matrixContainer.layer?.backgroundColor = NSColor.taskFrost.cgColor
        matrixContainer.layer?.borderWidth = 1
        matrixContainer.layer?.borderColor = NSColor.taskRing.cgColor

        matrixContainer.addSubview(matrixStack)

        NSLayoutConstraint.activate([
            matrixStack.leadingAnchor.constraint(equalTo: matrixContainer.leadingAnchor, constant: 18),
            matrixStack.trailingAnchor.constraint(equalTo: matrixContainer.trailingAnchor, constant: -18),
            matrixStack.topAnchor.constraint(equalTo: matrixContainer.topAnchor, constant: 18),
            matrixStack.bottomAnchor.constraint(equalTo: matrixContainer.bottomAnchor, constant: -18),
            matrixStack.heightAnchor.constraint(greaterThanOrEqualToConstant: 560)
        ])

        let rootStack = NSStackView(views: [headerStack, matrixContainer])
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        rootStack.orientation = .vertical
        rootStack.spacing = 18
        rootStack.alignment = .leading

        view.addSubview(rootStack)

        NSLayoutConstraint.activate([
            eyebrowLabel.leadingAnchor.constraint(equalTo: eyebrowCapsule.leadingAnchor, constant: 10),
            eyebrowLabel.trailingAnchor.constraint(equalTo: eyebrowCapsule.trailingAnchor, constant: -10),
            eyebrowLabel.topAnchor.constraint(equalTo: eyebrowCapsule.topAnchor, constant: 6),
            eyebrowLabel.bottomAnchor.constraint(equalTo: eyebrowCapsule.bottomAnchor, constant: -6),

            addTaskButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 138),
            addTaskButton.heightAnchor.constraint(equalToConstant: 40),

            rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            rootStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            rootStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -24),

            headerStack.leadingAnchor.constraint(equalTo: rootStack.leadingAnchor),
            headerStack.trailingAnchor.constraint(equalTo: rootStack.trailingAnchor),

            matrixContainer.leadingAnchor.constraint(equalTo: rootStack.leadingAnchor),
            matrixContainer.trailingAnchor.constraint(equalTo: rootStack.trailingAnchor)
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

    private func installDecorativeBackground() {
        let blobA = NSView()
        blobA.translatesAutoresizingMaskIntoConstraints = false
        blobA.wantsLayer = true
        blobA.layer?.backgroundColor = NSColor.taskAccent.withAlphaComponent(0.20).cgColor
        blobA.layer?.cornerRadius = 170

        let blobB = NSView()
        blobB.translatesAutoresizingMaskIntoConstraints = false
        blobB.wantsLayer = true
        blobB.layer?.backgroundColor = NSColor.taskMint.withAlphaComponent(0.55).cgColor
        blobB.layer?.cornerRadius = 140

        view.addSubview(blobA)
        view.addSubview(blobB)

        NSLayoutConstraint.activate([
            blobA.widthAnchor.constraint(equalToConstant: 340),
            blobA.heightAnchor.constraint(equalToConstant: 340),
            blobA.topAnchor.constraint(equalTo: view.topAnchor, constant: -150),
            blobA.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 90),

            blobB.widthAnchor.constraint(equalToConstant: 280),
            blobB.heightAnchor.constraint(equalToConstant: 280),
            blobB.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 120),
            blobB.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -90)
        ])
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
        alert.messageText = "Create Task"
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
            quadrantPicker.addItem(withTitle: quadrant.title)
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
    static let taskCanvas = NSColor(red: 0.963, green: 0.969, blue: 0.949, alpha: 1)
    static let taskMint = NSColor(red: 0.886, green: 0.965, blue: 0.835, alpha: 1)
    static let taskFrost = NSColor.white.withAlphaComponent(0.62)

    static let taskInk = NSColor(red: 0.055, green: 0.059, blue: 0.047, alpha: 1)
    static let taskMuted = NSColor(red: 0.40, green: 0.43, blue: 0.39, alpha: 1)

    static let taskAccent = NSColor(red: 0.624, green: 0.909, blue: 0.439, alpha: 1)
    static let taskAccentText = NSColor(red: 0.086, green: 0.200, blue: 0.0, alpha: 1)

    static let taskRing = NSColor(red: 0.055, green: 0.059, blue: 0.047, alpha: 0.12)
    static let taskSurface = NSColor(red: 0.993, green: 0.996, blue: 0.987, alpha: 1)
    static let taskSurfaceHover = NSColor(red: 0.973, green: 0.991, blue: 0.940, alpha: 1)

    static let taskCardWarm = NSColor(red: 0.985, green: 0.986, blue: 0.979, alpha: 1)
    static let taskCardFresh = NSColor(red: 0.970, green: 0.986, blue: 0.963, alpha: 1)
    static let taskCardMist = NSColor(red: 0.978, green: 0.985, blue: 0.986, alpha: 1)
    static let taskCardLight = NSColor(red: 0.989, green: 0.990, blue: 0.985, alpha: 1)
}

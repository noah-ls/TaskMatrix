import Cocoa

final class ArchiveViewController: NSViewController {
    var onRestoreRequested: ((String) -> Void)?
    var onDeleteRequested: ((String) -> Void)?

    private let countLabel = NSTextField(labelWithString: "")
    private let listStack = NSStackView()
    private let emptyLabel = NSTextField(labelWithString: "No archived tasks")
    private var tasks: [TaskItem] = []

    func update(tasks: [TaskItem]) {
        self.tasks = tasks
        if isViewLoaded {
            rebuildList()
        }
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 680, height: 520))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.taskCanvas.cgColor

        let titleLabel = NSTextField(labelWithString: "Archived Tasks")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 20, weight: .black)
        titleLabel.textColor = NSColor.taskInk

        let subtitleLabel = NSTextField(labelWithString: "Completed tasks moved out of the active matrix.")
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        subtitleLabel.textColor = NSColor.taskMuted

        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.font = .monospacedDigitSystemFont(ofSize: 11.5, weight: .bold)
        countLabel.textColor = NSColor.taskMuted
        countLabel.alignment = .right

        let headerSpacer = NSView()
        headerSpacer.translatesAutoresizingMaskIntoConstraints = false
        headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        headerSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let titleStack = NSStackView(views: [titleLabel, subtitleLabel])
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 2

        let headerRow = NSStackView(views: [titleStack, headerSpacer, countLabel])
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 12

        listStack.translatesAutoresizingMaskIntoConstraints = false
        listStack.orientation = .vertical
        listStack.alignment = .leading
        listStack.spacing = 8

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.font = .systemFont(ofSize: 13, weight: .medium)
        emptyLabel.textColor = NSColor.taskMuted.withAlphaComponent(0.75)

        let contentView = ArchiveFlippedView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(listStack)
        contentView.addSubview(emptyLabel)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.documentView = contentView

        view.addSubview(headerRow)
        view.addSubview(scrollView)

        let listBottom = listStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        listBottom.priority = NSLayoutConstraint.Priority(999)

        NSLayoutConstraint.activate([
            headerRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            headerRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22),
            headerRow.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            scrollView.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 16),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -18),

            contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

            listStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            listStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            listStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            listBottom,

            emptyLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            emptyLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            emptyLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8)
        ])

        rebuildList()
    }

    private func rebuildList() {
        listStack.arrangedSubviews.forEach { subview in
            listStack.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        countLabel.stringValue = "\(tasks.count) archived"
        emptyLabel.isHidden = !tasks.isEmpty

        for task in tasks {
            let row = ArchivedTaskRowView(task: task)
            row.onRestoreRequested = { [weak self] in
                self?.onRestoreRequested?(task.id)
            }
            row.onDeleteRequested = { [weak self] in
                self?.onDeleteRequested?(task.id)
            }
            listStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: listStack.widthAnchor).isActive = true
        }
    }
}

private final class ArchivedTaskRowView: NSView {
    var onRestoreRequested: (() -> Void)?
    var onDeleteRequested: (() -> Void)?

    private let task: TaskItem

    init(task: TaskItem) {
        self.task = task
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.backgroundColor = NSColor.taskSurface.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.taskRing.cgColor

        let dot = NSView()
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.wantsLayer = true
        dot.layer?.backgroundColor = task.quadrant.accentColor.cgColor
        dot.layer?.cornerRadius = 5

        let titleLabel = NSTextField(labelWithString: task.title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = NSColor.taskInk
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1

        let completedText = task.completedAt.map { "Completed \(DueDateFormatting.shortLabel(for: $0))" }
            ?? "Completed"
        let archivedText = task.archivedAt.map { "Archived \(DueDateFormatting.shortLabel(for: $0))" }
            ?? "Archived"
        let metaLabel = NSTextField(labelWithString: "\(task.quadrant.strategy) | \(completedText) | \(archivedText)")
        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.font = .systemFont(ofSize: 11, weight: .medium)
        metaLabel.textColor = NSColor.taskMuted
        metaLabel.lineBreakMode = .byTruncatingTail
        metaLabel.maximumNumberOfLines = 1

        let textStack = NSStackView(views: [titleLabel, metaLabel])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

        let restoreButton = PillButton(
            title: "Restore",
            style: .outline,
            target: self,
            action: #selector(handleRestore(_:))
        )

        let deleteButton = PillButton(
            title: "Delete",
            style: .subtle,
            target: self,
            action: #selector(handleDelete(_:))
        )

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let rowStack = NSStackView(views: [dot, textStack, spacer, restoreButton, deleteButton])
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.spacing = 10

        addSubview(rowStack)

        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 10),
            dot.heightAnchor.constraint(equalToConstant: 10),

            rowStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            rowStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            rowStack.topAnchor.constraint(equalTo: topAnchor, constant: 11),
            rowStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -11),

            textStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 64)
        ])
    }

    @objc
    private func handleRestore(_ sender: NSButton) {
        onRestoreRequested?()
    }

    @objc
    private func handleDelete(_ sender: NSButton) {
        onDeleteRequested?()
    }
}

private final class ArchiveFlippedView: NSView {
    override var isFlipped: Bool { true }
}

import Cocoa

/// One indented subtask line inside a task row card.
final class SubtaskRowView: NSView {
    var onToggle: ((Bool) -> Void)?
    var onEditRequested: (() -> Void)?
    var onDeleteRequested: (() -> Void)?

    private let subtask: SubTask
    private let titleLabel = NSTextField(labelWithString: "")
    private lazy var checkbox: NSButton = {
        let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(handleCheckboxChange(_:)))
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        checkbox.setButtonType(.switch)
        checkbox.contentTintColor = NSColor.taskAccentText
        checkbox.controlSize = .small
        return checkbox
    }()

    init(subtask: SubTask) {
        self.subtask = subtask
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu(title: "Subtask")

        let renameItem = NSMenuItem(title: "Rename…", action: #selector(handleRename(_:)), keyEquivalent: "")
        renameItem.target = self
        menu.addItem(renameItem)
        menu.addItem(.separator())

        let deleteItem = NSMenuItem(title: "Delete", action: #selector(handleDelete(_:)), keyEquivalent: "")
        deleteItem.target = self
        menu.addItem(deleteItem)

        return menu
    }

    private func setupUI() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1

        if subtask.isCompleted {
            checkbox.state = .on
            titleLabel.attributedStringValue = NSAttributedString(
                string: subtask.title,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12, weight: .regular),
                    .foregroundColor: NSColor.taskMuted.withAlphaComponent(0.8),
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .strikethroughColor: NSColor.taskMuted.withAlphaComponent(0.8)
                ]
            )
        } else {
            checkbox.state = .off
            titleLabel.attributedStringValue = NSAttributedString(
                string: subtask.title,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                    .foregroundColor: NSColor.taskInk.withAlphaComponent(0.85)
                ]
            )
        }

        let rowStack = NSStackView(views: [checkbox, titleLabel])
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.spacing = 7

        addSubview(rowStack)

        NSLayoutConstraint.activate([
            checkbox.widthAnchor.constraint(equalToConstant: 16),
            checkbox.heightAnchor.constraint(equalToConstant: 16),

            rowStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 27),
            rowStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            rowStack.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            rowStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 24)
        ])
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            // Open the subtask editor and swallow the event so the parent
            // row doesn't also open its own editor.
            onEditRequested?()
        } else {
            // Single click bubbles up so the parent row gets selected.
            super.mouseDown(with: event)
        }
    }

    @objc
    private func handleCheckboxChange(_ sender: NSButton) {
        onToggle?(sender.state == .on)
    }

    @objc
    private func handleRename(_ sender: NSMenuItem) {
        onEditRequested?()
    }

    @objc
    private func handleDelete(_ sender: NSMenuItem) {
        onDeleteRequested?()
    }
}

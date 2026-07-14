import Cocoa

/// One selectable quadrant tile inside the task form's 2x2 picker.
final class QuadrantOptionView: NSView {
    let quadrant: Quadrant
    var onSelect: ((Quadrant) -> Void)?

    var isChosen = false {
        didSet { refreshStyle() }
    }

    init(quadrant: Quadrant) {
        self.quadrant = quadrant
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupUI()
        refreshStyle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 10

        let dot = NSView()
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.wantsLayer = true
        dot.layer?.backgroundColor = quadrant.accentColor.cgColor
        dot.layer?.cornerRadius = 4

        let strategyLabel = NSTextField(labelWithString: quadrant.strategy)
        strategyLabel.translatesAutoresizingMaskIntoConstraints = false
        strategyLabel.font = .systemFont(ofSize: 13, weight: .bold)
        strategyLabel.textColor = NSColor.taskInk

        let titleRow = NSStackView(views: [dot, strategyLabel])
        titleRow.translatesAutoresizingMaskIntoConstraints = false
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 6

        let captionLabel = NSTextField(labelWithString: "")
        captionLabel.translatesAutoresizingMaskIntoConstraints = false
        let captionText = NSMutableAttributedString(string: quadrant.subtitle)
        captionText.addAttributes(
            [
                .font: NSFont.systemFont(ofSize: 9, weight: .semibold),
                .foregroundColor: NSColor.taskMuted,
                .kern: 0.5
            ],
            range: NSRange(location: 0, length: captionText.length)
        )
        captionLabel.attributedStringValue = captionText

        let contentStack = NSStackView(views: [titleRow, captionLabel])
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 3

        addSubview(contentStack)

        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),

            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 54)
        ])

        let clickRecognizer = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        addGestureRecognizer(clickRecognizer)
    }

    private func refreshStyle() {
        guard let layer else { return }

        if isChosen {
            layer.borderWidth = 2
            layer.borderColor = quadrant.accentColor.cgColor
            layer.backgroundColor = quadrant.accentColor.withAlphaComponent(0.08).cgColor
        } else {
            layer.borderWidth = 1
            layer.borderColor = NSColor.taskRing.cgColor
            layer.backgroundColor = NSColor.taskSurface.cgColor
        }
    }

    @objc
    private func handleClick(_ recognizer: NSClickGestureRecognizer) {
        onSelect?(quadrant)
    }
}

/// Focusable wrapper around the quadrant tiles. While focused, Tab cycles
/// the selected quadrant and arrow keys move it; Shift+Tab leaves the picker.
final class QuadrantPickerView: NSView {
    var onCycleSelection: ((Int) -> Void)?
    var onFocusPrevious: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 13
        layer?.borderWidth = 2
        layer?.borderColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func becomeFirstResponder() -> Bool {
        layer?.borderColor = NSColor.taskAccentText.withAlphaComponent(0.35).cgColor
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        layer?.borderColor = NSColor.clear.cgColor
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        let tabKeyCode: UInt16 = 48
        let leftArrow: UInt16 = 123
        let rightArrow: UInt16 = 124
        let downArrow: UInt16 = 125
        let upArrow: UInt16 = 126

        switch event.keyCode {
        case tabKeyCode where event.modifierFlags.contains(.shift):
            onFocusPrevious?()
        case tabKeyCode, rightArrow, downArrow:
            onCycleSelection?(1)
        case leftArrow, upArrow:
            onCycleSelection?(-1)
        default:
            super.keyDown(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
}

import Cocoa

/// Pill CTA in the Wise style: grows on hover, compresses on click.
final class PillButton: NSButton {
    enum Style {
        case primary
        case subtle
    }

    private var trackingAreaRef: NSTrackingArea?

    override var isEnabled: Bool {
        didSet {
            alphaValue = isEnabled ? 1 : 0.4
        }
    }

    init(title: String, style: Style = .primary, target: AnyObject?, action: Selector?) {
        super.init(frame: .zero)
        self.target = target
        self.action = action

        translatesAutoresizingMaskIntoConstraints = false
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 18

        let backgroundColor: NSColor
        let textColor: NSColor
        switch style {
        case .primary:
            backgroundColor = .taskAccent
            textColor = .taskAccentText
        case .subtle:
            backgroundColor = NSColor.taskInk.withAlphaComponent(0.06)
            textColor = .taskInk
        }

        layer?.backgroundColor = backgroundColor.cgColor
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 14, weight: .bold),
                .foregroundColor: textColor
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
        // Scale around the center without touching anchorPoint/position —
        // AppKit owns the layer geometry and moving it shifts the button.
        var transform = CATransform3DMakeTranslation(bounds.midX, bounds.midY, 0)
        transform = CATransform3DScale(transform, scale, scale, 1)
        transform = CATransform3DTranslate(transform, -bounds.midX, -bounds.midY, 0)
        layer.transform = transform
    }
}

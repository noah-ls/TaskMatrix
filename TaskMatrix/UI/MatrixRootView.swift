import Cocoa

/// Root view: first responder for the matrix, catches Delete presses and
/// clicks on empty space (which clear the selection).
final class MatrixRootView: NSView {
    var onDeleteKeyPressed: (() -> Void)?
    var onBackgroundClicked: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let backspaceKeyCode: UInt16 = 51
        let forwardDeleteKeyCode: UInt16 = 117

        if event.keyCode == backspaceKeyCode || event.keyCode == forwardDeleteKeyCode {
            onDeleteKeyPressed?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        onBackgroundClicked?()
        super.mouseDown(with: event)
    }
}

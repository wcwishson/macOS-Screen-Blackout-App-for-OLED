import Cocoa

final class BlackoutView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        quit()
    }

    override func rightMouseDown(with event: NSEvent) {
        quit()
    }

    override func otherMouseDown(with event: NSEvent) {
        quit()
    }

    override func keyDown(with event: NSEvent) {
        // Ignore keys.
    }

    private func quit() {
        NSApp.terminate(nil)
    }
}

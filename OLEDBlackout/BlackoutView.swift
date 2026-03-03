import Cocoa

final class BlackoutView: NSView {
    private let transparentCursor: NSCursor = {
        let image = NSImage(size: NSSize(width: 16, height: 16))
        return NSCursor(image: image, hotSpot: .zero)
    }()
    private var cursorTrackingArea: NSTrackingArea?

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

    override func updateTrackingAreas() {
        if let cursorTrackingArea {
            removeTrackingArea(cursorTrackingArea)
        }

        let options: NSTrackingArea.Options = [.activeAlways, .inVisibleRect, .cursorUpdate, .mouseMoved]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
        cursorTrackingArea = trackingArea
        super.updateTrackingAreas()
    }

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: transparentCursor)
    }

    override func cursorUpdate(with event: NSEvent) {
        transparentCursor.set()
    }

    override func mouseMoved(with event: NSEvent) {
        transparentCursor.set()
    }

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

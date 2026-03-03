import Cocoa

final class BlackoutWindow: NSWindow {
    init(screen: NSScreen, level: NSWindow.Level) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        setFrame(screen.frame, display: true)

        isOpaque = true
        backgroundColor = .black
        hasShadow = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        isMovableByWindowBackground = false
        self.level = level
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        animationBehavior = .none

        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        contentView = BlackoutView(frame: screen.frame)
        makeFirstResponder(contentView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        // Ignore all key presses.
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Swallow key equivalents (e.g., Cmd+Q).
        true
    }
}

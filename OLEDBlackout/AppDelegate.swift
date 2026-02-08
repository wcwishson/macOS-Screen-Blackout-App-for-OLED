import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windows: [BlackoutWindow] = []
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var cursorHidden = false
    private var topmostTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Remove menu to avoid keyboard shortcuts like Cmd+Q.
        NSApp.mainMenu = NSMenu()

        NSApp.activate(ignoringOtherApps: true)
        createWindows()
        applyPresentationOptions()
        hideCursor()
        scheduleInitialCursorRehide()
        startTopmostTimer()

        // Avoid quitting immediately from the mouse click used to launch the app.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.installEventMonitors()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopTopmostTimer()
        showCursorIfNeeded()
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
    }

    private func createWindows() {
        for screen in NSScreen.screens {
            let window = BlackoutWindow(screen: screen)
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }
    }

    private func installEventMonitors() {
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.quit()
            return nil
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            self?.quit()
        }
    }

    private func quit() {
        stopTopmostTimer()
        showCursorIfNeeded()
        NSApp.terminate(nil)
    }

    private func hideCursor() {
        guard !cursorHidden else { return }
        NSCursor.hide()
        cursorHidden = true
    }

    private func forceCursorHiddenIfNeeded() {
        guard cursorHidden else { return }
        // Keep the hide count stable while forcing hidden state back.
        NSCursor.unhide()
        NSCursor.hide()
    }

    private func showCursorIfNeeded() {
        guard cursorHidden else { return }
        NSCursor.unhide()
        cursorHidden = false
    }

    private func applyPresentationOptions() {
        // Keep the menu bar and dock hidden while the blackout is active.
        NSApp.presentationOptions = [.hideDock, .hideMenuBar]
    }

    private func startTopmostTimer() {
        topmostTimer?.invalidate()
        topmostTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.reassertTopmost()
        }
    }

    private func stopTopmostTimer() {
        topmostTimer?.invalidate()
        topmostTimer = nil
    }

    private func reassertTopmost() {
        applyPresentationOptions()
        forceCursorHiddenIfNeeded()
        for window in windows {
            window.level = .screenSaver
            window.orderFrontRegardless()
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func scheduleInitialCursorRehide() {
        let delays: [TimeInterval] = [0.15, 0.5, 1.0]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.forceCursorHiddenIfNeeded()
            }
        }
    }
}

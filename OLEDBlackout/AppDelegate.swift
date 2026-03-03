import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let desiredWindowLevel: NSWindow.Level = {
        let screenSaverLevel = NSWindow.Level.screenSaver.rawValue
        let shieldingLevel = Int(CGShieldingWindowLevel())
        let assistiveLevel = Int(CGWindowLevelForKey(.assistiveTechHighWindow))
        let maximumLevel = Int(CGWindowLevelForKey(.maximumWindow))
        return NSWindow.Level(rawValue: min(max(max(screenSaverLevel, shieldingLevel), assistiveLevel), maximumLevel))
    }()
    private let topmostInterval: TimeInterval = 0.5
    private let cursorRehideThrottle: TimeInterval = 0.05
    private let cursorHardRehideInterval: TimeInterval = 15.0
    private let maxNSCursorHideDepth = 4096
    private let maxDisplayCursorHideDepth = 4096
    private let transparentCursor: NSCursor = {
        let image = NSImage(size: NSSize(width: 16, height: 16))
        return NSCursor(image: image, hotSpot: .zero)
    }()

    private var windows: [BlackoutWindow] = []
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    private var globalMotionMonitor: Any?
    private var localMotionMonitor: Any?
    private var appNotificationObservers: [NSObjectProtocol] = []
    private var workspaceNotificationObservers: [NSObjectProtocol] = []
    private var cursorHidden = false
    private var nsCursorHideDepth = 0
    private var displayCursorHideDepth: [CGDirectDisplayID: Int] = [:]
    private var lastCursorRehideAt: TimeInterval = 0
    private var lastHardCursorHideAt: TimeInterval = 0
    private var topmostTimer: Timer?
    private var processActivity: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Remove menu to avoid keyboard shortcuts like Cmd+Q.
        NSApp.mainMenu = NSMenu()

        processActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep, .latencyCritical],
            reason: "Keep blackout overlay and cursor suppression active"
        )

        NSApp.activate(ignoringOtherApps: true)
        createWindows()
        applyPresentationOptions()
        hideCursor()
        installReassertionObservers()
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
        if let processActivity {
            ProcessInfo.processInfo.endActivity(processActivity)
            self.processActivity = nil
        }
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
        }
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
        }
        if let globalMotionMonitor {
            NSEvent.removeMonitor(globalMotionMonitor)
        }
        if let localMotionMonitor {
            NSEvent.removeMonitor(localMotionMonitor)
        }
        for observer in appNotificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        for observer in workspaceNotificationObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        appNotificationObservers.removeAll()
        workspaceNotificationObservers.removeAll()
    }

    private func createWindows() {
        windows.forEach { $0.close() }
        windows.removeAll(keepingCapacity: true)

        for screen in NSScreen.screens {
            let window = BlackoutWindow(screen: screen, level: desiredWindowLevel)
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }
    }

    private func installEventMonitors() {
        let clickMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        let motionMask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .scrollWheel]

        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: clickMask) { [weak self] event in
            self?.quit()
            return nil
        }

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: clickMask) { [weak self] _ in
            self?.quit()
        }

        localMotionMonitor = NSEvent.addLocalMonitorForEvents(matching: motionMask) { [weak self] event in
            self?.requestCursorRehide()
            return event
        }

        globalMotionMonitor = NSEvent.addGlobalMonitorForEvents(matching: motionMask) { [weak self] _ in
            self?.requestCursorRehide()
        }
    }

    private func quit() {
        stopTopmostTimer()
        showCursorIfNeeded()
        NSApp.terminate(nil)
    }

    private func hideCursor() {
        guard !cursorHidden else { return }
        pushNSCursorHide()
        cursorHidden = true
        lastHardCursorHideAt = ProcessInfo.processInfo.systemUptime
        applyTransparentCursor()
        hideCursorOnActiveDisplaysIfNeeded(force: true)
    }

    private func forceCursorHiddenIfNeeded() {
        guard cursorHidden else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if nsCursorHideDepth == 0 || now - lastHardCursorHideAt >= cursorHardRehideInterval {
            pushNSCursorHide()
            hideCursorOnActiveDisplaysIfNeeded(force: true)
            lastHardCursorHideAt = now
        } else {
            hideCursorOnActiveDisplaysIfNeeded(force: false)
        }
        applyTransparentCursor()
    }

    private func showCursorIfNeeded() {
        guard cursorHidden else { return }
        showCursorOnTrackedDisplays()
        displayCursorHideDepth.removeAll()
        NSCursor.arrow.set()
        while nsCursorHideDepth > 0 {
            NSCursor.unhide()
            nsCursorHideDepth -= 1
        }
        lastHardCursorHideAt = 0
        cursorHidden = false
    }

    private func applyPresentationOptions() {
        // Keep the menu bar and dock hidden while the blackout is active.
        NSApp.presentationOptions = [.hideDock, .hideMenuBar]
    }

    private func startTopmostTimer() {
        topmostTimer?.invalidate()
        let timer = Timer(timeInterval: topmostInterval, repeats: true) { [weak self] _ in
            self?.reassertTopmost()
        }
        RunLoop.main.add(timer, forMode: .common)
        topmostTimer = timer
    }

    private func stopTopmostTimer() {
        topmostTimer?.invalidate()
        topmostTimer = nil
    }

    private func reassertTopmost() {
        applyPresentationOptions()
        forceCursorHiddenIfNeeded()
        for window in windows {
            if let screen = window.screen {
                window.setFrame(screen.frame, display: true)
            }
            window.level = desiredWindowLevel
            window.orderFrontRegardless()
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func requestCursorRehide() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastCursorRehideAt >= cursorRehideThrottle else { return }
        lastCursorRehideAt = now
        forceCursorHiddenIfNeeded()
    }

    private func scheduleInitialCursorRehide() {
        let delays: [TimeInterval] = [0.05, 0.15, 0.35, 0.7, 1.2]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.forceCursorHiddenIfNeeded()
            }
        }
    }

    private func installReassertionObservers() {
        let notificationCenter = NotificationCenter.default
        let workspaceCenter = NSWorkspace.shared.notificationCenter

        let appDidResignObserver = notificationCenter.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            self?.reassertTopmost()
        }

        let appDidBecomeObserver = notificationCenter.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            self?.reassertTopmost()
        }

        let screenParamsObserver = notificationCenter.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            self?.createWindows()
            self?.reassertTopmost()
        }

        let spaceObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reassertTopmost()
        }

        let screensDidWakeObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.createWindows()
            self?.reassertTopmost()
        }

        let sessionDidBecomeActiveObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reassertTopmost()
        }

        appNotificationObservers = [appDidResignObserver, appDidBecomeObserver, screenParamsObserver]
        workspaceNotificationObservers = [spaceObserver, screensDidWakeObserver, sessionDidBecomeActiveObserver]
    }

    private func applyTransparentCursor() {
        transparentCursor.set()
    }

    private func pushNSCursorHide() {
        guard nsCursorHideDepth < maxNSCursorHideDepth else { return }
        NSCursor.hide()
        nsCursorHideDepth += 1
    }

    private func activeDisplayIDs() -> [CGDirectDisplayID] {
        let displayIDs = NSScreen.screens.compactMap { screen -> CGDirectDisplayID? in
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            return CGDirectDisplayID(screenNumber.uint32Value)
        }
        if displayIDs.isEmpty {
            return [CGMainDisplayID()]
        }
        return displayIDs
    }

    private func hideCursorOnActiveDisplaysIfNeeded(force: Bool) {
        for displayID in activeDisplayIDs() {
            let currentDepth = displayCursorHideDepth[displayID, default: 0]
            guard force || currentDepth == 0 else { continue }
            guard currentDepth < maxDisplayCursorHideDepth else { continue }
            if CGDisplayHideCursor(displayID) == .success {
                displayCursorHideDepth[displayID] = currentDepth + 1
            }
        }
    }

    private func showCursorOnTrackedDisplays() {
        for (displayID, depth) in displayCursorHideDepth {
            guard depth > 0 else { continue }
            for _ in 0..<depth {
                _ = CGDisplayShowCursor(displayID)
            }
        }
    }
}

import Cocoa
import ApplicationServices

protocol MemoWatcherDelegate: AnyObject {
    func memoWatcherDidAttach()
    func memoWatcherDidDetach()
    func memoWatcherDidDismiss()
}

class MemoWatcher {
    weak var delegate: MemoWatcherDelegate?
    private var observedPid: pid_t = 0
    private var observer: AXObserver?
    private var appRef: AXUIElement?
    private(set) var isAttached: Bool = false

    func start() {
        let ws = NSWorkspace.shared
        ws.notificationCenter.addObserver(self, selector: #selector(appLaunched(_:)),
            name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        ws.notificationCenter.addObserver(self, selector: #selector(appTerminated(_:)),
            name: NSWorkspace.didTerminateApplicationNotification, object: nil)

        for app in ws.runningApplications {
            if app.bundleIdentifier == "com.nebula.memo" {
                attach(pid: app.processIdentifier)
                break
            }
        }
    }

    @objc private func appLaunched(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier == "com.nebula.memo" else { return }
        attach(pid: app.processIdentifier)
    }

    @objc private func appTerminated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier == "com.nebula.memo" else { return }
        detach()
    }

    private func attach(pid: pid_t) {
        detach()
        observedPid = pid
        let app = AXUIElementCreateApplication(pid)
        self.appRef = app

        var obs: AXObserver?
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let err = AXObserverCreate(pid, { (_: AXObserver, element: AXUIElement, notification: CFString, refcon: UnsafeMutableRawPointer?) in
            guard let refcon = refcon else { return }
            let watcher = Unmanaged<MemoWatcher>.fromOpaque(refcon).takeUnretainedValue()
            watcher.handleNotification(element: element, notification: notification as String)
        }, &obs)

        guard err == .success, let observer = obs else { return }
        self.observer = observer

        let notifications: [String] = [
            kAXWindowCreatedNotification as String,
            kAXFocusedWindowChangedNotification as String,
            kAXMainWindowChangedNotification as String,
        ]
        for n in notifications {
            AXObserverAddNotification(observer, app, n as CFString, selfPtr)
        }
        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)

        isAttached = true
        delegate?.memoWatcherDidAttach()

        // Memo's AX windows are not ready immediately after launch.
        // Retry several times over the first 15 seconds.
        checkAndDismiss()
        for delay in [1.0, 3.0, 5.0, 8.0, 12.0, 15.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.checkAndDismiss()
            }
        }
    }

    private func detach() {
        if let observer = self.observer {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
            self.observer = nil
        }
        appRef = nil
        observedPid = 0
        if isAttached {
            isAttached = false
            delegate?.memoWatcherDidDetach()
        }
    }

    private func handleNotification(element: AXUIElement, notification: String) {
        // No delay — dismiss as fast as possible to avoid visual flash
        if notification == kAXWindowCreatedNotification as String {
            dismissIfPremium(window: element)
        }
        checkAndDismiss()
    }

    private func dismissIfPremium(window: AXUIElement) {
        var titleValue: AnyObject?
        AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
        guard let title = titleValue as? String, title == "Airmail Pro" else { return }

        // Move window off-screen immediately to prevent visual flash
        var offScreen = CGPoint(x: -10000, y: -10000)
        let posValue = AXValueCreate(.cgPoint, &offScreen)!
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)

        if let closeButton = findCloseButton(in: window) {
            AXUIElementPerformAction(closeButton, kAXPressAction as CFString)
            delegate?.memoWatcherDidDismiss()
        }
    }

    private func findCloseButton(in element: AXUIElement, depth: Int = 0) -> AXUIElement? {
        guard depth < 5 else { return nil }

        var children: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        guard let elements = children as? [AXUIElement] else { return nil }

        for child in elements {
            var subrole: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXSubroleAttribute as CFString, &subrole)
            if let sr = subrole as? String, sr == "AXCloseButton" {
                return child
            }
            if let found = findCloseButton(in: child, depth: depth + 1) {
                return found
            }
        }
        return nil
    }

    private func checkAndDismiss() {
        guard let app = self.appRef else { return }

        for attr in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] as [String] {
            var windowValue: AnyObject?
            if AXUIElementCopyAttributeValue(app, attr as CFString, &windowValue) == .success {
                dismissIfPremium(window: windowValue as! AXUIElement)
            }
        }

        var listValue: AnyObject?
        if AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &listValue) == .success,
           let windows = listValue as? [AXUIElement] {
            for w in windows {
                dismissIfPremium(window: w)
            }
        }
    }
}

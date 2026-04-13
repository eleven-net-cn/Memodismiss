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
        let appRef = AXUIElementCreateApplication(pid)

        var obs: AXObserver?
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let err = AXObserverCreate(pid, { (_: AXObserver, element: AXUIElement, notification: CFString, refcon: UnsafeMutableRawPointer?) in
            guard let refcon = refcon else { return }
            let watcher = Unmanaged<MemoWatcher>.fromOpaque(refcon).takeUnretainedValue()
            watcher.handleNotification(element: element, notification: notification as String)
        }, &obs)

        guard err == .success, let observer = obs else { return }
        self.observer = observer

        AXObserverAddNotification(observer, appRef, kAXWindowCreatedNotification as CFString, selfPtr)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)

        isAttached = true
        delegate?.memoWatcherDidAttach()

        checkAndDismiss(appRef: appRef)
    }

    private func detach() {
        if let observer = self.observer {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
            self.observer = nil
        }
        observedPid = 0
        if isAttached {
            isAttached = false
            delegate?.memoWatcherDidDetach()
        }
    }

    private func handleNotification(element: AXUIElement, notification: String) {
        if notification == kAXWindowCreatedNotification as String {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.dismissIfPremium(window: element)
            }
        }
    }

    private func dismissIfPremium(window: AXUIElement) {
        var titleValue: AnyObject?
        AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
        guard let title = titleValue as? String, title == "Airmail Pro" else { return }

        var children: AnyObject?
        AXUIElementCopyAttributeValue(window, kAXChildrenAttribute as CFString, &children)
        guard let elements = children as? [AXUIElement] else { return }

        for element in elements {
            var subrole: AnyObject?
            AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole)
            if let sr = subrole as? String, sr == "AXCloseButton" {
                AXUIElementPerformAction(element, kAXPressAction as CFString)
                delegate?.memoWatcherDidDismiss()
                return
            }
        }
    }

    private func checkAndDismiss(appRef: AXUIElement) {
        var windowsValue: AnyObject?
        AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsValue)
        guard let windows = windowsValue as? [AXUIElement] else { return }
        for w in windows {
            dismissIfPremium(window: w)
        }
    }
}

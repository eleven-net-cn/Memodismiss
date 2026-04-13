import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, MemoWatcherDelegate {
    private var statusItem: NSStatusItem!
    private var watcher: MemoWatcher!
    private var dismissCount: Int = 0

    private var statusMenuItem: NSMenuItem!
    private var launchAtLoginItem: NSMenuItem!

    private let launchAgentLabel = "com.github.MemoDismiss"
    private var launchAgentPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/LaunchAgents/\(launchAgentLabel).plist"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibilityIfNeeded()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "M"
            button.font = NSFont.boldSystemFont(ofSize: 13)
        }

        let menu = NSMenu()

        statusMenuItem = NSMenuItem(title: "Memo: not running", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        launchAtLoginItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(launchAtLoginItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu

        watcher = MemoWatcher()
        watcher.delegate = self
        watcher.start()
    }

    // MARK: - MemoWatcherDelegate

    func memoWatcherDidAttach() {
        statusMenuItem.title = "Memo: running (watching)"
    }

    func memoWatcherDidDetach() {
        statusMenuItem.title = "Memo: not running"
    }

    func memoWatcherDidDismiss() {
        dismissCount += 1
        statusMenuItem.title = "Memo: running (dismissed \(dismissCount)x)"
    }

    // MARK: - Accessibility

    private func requestAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Launch at Login

    @objc private func toggleLaunchAtLogin() {
        if isLaunchAtLoginEnabled() {
            removeLaunchAgent()
            launchAtLoginItem.state = .off
        } else {
            installLaunchAgent()
            launchAtLoginItem.state = .on
        }
    }

    private func isLaunchAtLoginEnabled() -> Bool {
        return FileManager.default.fileExists(atPath: launchAgentPath)
    }

    private func installLaunchAgent() {
        let appPath = Bundle.main.bundlePath
        let plist: [String: Any] = [
            "Label": launchAgentLabel,
            "ProgramArguments": ["\(appPath)/Contents/MacOS/MemoDismiss"],
            "RunAtLoad": true,
            "KeepAlive": false
        ]
        let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let dir = (launchAgentPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: launchAgentPath, contents: data)
    }

    private func removeLaunchAgent() {
        try? FileManager.default.removeItem(atPath: launchAgentPath)
    }

    // MARK: - Quit

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

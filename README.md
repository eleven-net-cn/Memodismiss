# MemoDismiss

A lightweight macOS menu bar utility that automatically closes the recurring "Airmail Pro" premium popup in [Memo](https://apps.apple.com/app/id1212409035).

## How it works

MemoDismiss uses the macOS Accessibility API to monitor Memo in an event-driven manner:

1. Listens for Memo launch/quit via `NSWorkspace` notifications
2. When Memo is running, registers an `AXObserver` for window creation events
3. When a new window titled "Airmail Pro" appears, automatically clicks its close button

Zero CPU usage when idle. No polling.

## Requirements

- macOS 12.0+
- Xcode Command Line Tools (`xcode-select --install`)
- **Accessibility permission** must be granted in System Settings > Privacy & Security > Accessibility

## Install

### Option 1: Download from Releases

Download `MemoDismiss.app` from [Releases](../../releases), move it to `/Applications`, and open it.

### Option 2: Build from source

```bash
git clone https://github.com/YOUR_USERNAME/MemoDismiss.git
cd MemoDismiss
make
# The app is at build/MemoDismiss.app — double-click to run
# Or install to /Applications:
make install
```

## Usage

After launching, a **M** icon appears in the menu bar with:

- **Status** — shows whether Memo is running and how many popups have been dismissed
- **Launch at Login** — toggle to start MemoDismiss automatically on login
- **Quit** — exit the app

On first launch, macOS will prompt you to grant Accessibility permission. The app cannot function without it.

## Uninstall

```bash
make uninstall
```

Or manually delete `/Applications/MemoDismiss.app` and `~/Library/LaunchAgents/com.github.MemoDismiss.plist`.

## License

[MIT](LICENSE)

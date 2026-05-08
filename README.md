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

Download the latest **`MemoDismiss-vX.Y.Z.dmg`** from [Releases](../../releases), open it, and drag **MemoDismiss** onto the **Applications** shortcut. A `.zip` is also published for users who prefer it.

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

## Updating to a new version

> **Important:** You must re-grant Accessibility permission every time you install a new release.

MemoDismiss is distributed with an ad-hoc signature (no paid Apple Developer certificate), so macOS treats every new build as a different app even though the name and bundle id stay the same. Your old authorization is tied to the previous build's code hash, not to the new one.

Upgrade steps:

1. Quit MemoDismiss (menu bar **M** → **Quit**).
2. Replace `/Applications/MemoDismiss.app` with the new version (re-run `make install`, drag the new `.app` from the mounted DMG over the old one, or unzip the published `.zip` and replace it).
3. Open **System Settings → Privacy & Security → Accessibility**.
4. Find **MemoDismiss** in the list and remove it with the **−** button. If two entries appear, remove both.
5. Launch the new `/Applications/MemoDismiss.app`. macOS will prompt for Accessibility access — click **Open System Settings** and toggle **MemoDismiss** on.
6. Confirm the menu bar status changes from "Memo: not running" to "Memo: running (watching)" once Memo is open.

If the popup still appears after the upgrade, permission did not transfer — repeat step 4 to make sure the stale entry is gone.

## Uninstall

```bash
make uninstall
```

Or manually delete `/Applications/MemoDismiss.app` and `~/Library/LaunchAgents/com.github.MemoDismiss.plist`.

## License

[MIT](LICENSE)

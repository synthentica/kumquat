import AppKit
import Carbon.HIToolbox
import KumquatCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let dragMonitor = DragMonitor()
    private let wheel = WheelController()
    private let runner = OperationRunner()
    private let settingsWindow = SettingsWindowController()
    private var statusItem: NSStatusItem?
    private var hotKey: HotKey?
    private var spinTimer: Timer?
    private var stopItem: NSMenuItem?
    private var hintItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setUpStatusItem()

        wheel.onPerform = { [weak self] operation, urls in
            self?.runner.run(operation, on: urls)
        }
        runner.onBusyChanged = { [weak self] busy in
            self?.setSpinning(busy)
            self?.stopItem?.isHidden = !busy
        }
        dragMonitor.onWheelKey = { [weak self] chosen in
            guard let self else { return }
            if self.wheel.isVisible {
                self.wheel.switchTo(chosen)
            } else {
                self.wheel.show(urls: self.dragMonitor.draggedURLs(), wheel: chosen, at: NSEvent.mouseLocation, keyboard: false)
            }
        }
        dragMonitor.onDragEnded = { [weak self] in self?.wheel.dragEnded() }
        dragMonitor.start()

        hotKey = HotKey(keyCode: kVK_ANSI_C, modifiers: controlKey | optionKey) { [weak self] in
            self?.convertFinderSelection()
        }

        prewarm()

        if !UserDefaults.standard.bool(forKey: "hasLaunched") {
            UserDefaults.standard.set(true, forKey: "hasLaunched")
            settingsWindow.show()
        }
    }

    /// Does the one-time setup behind the wheel and the toast right after launch, while nothing is waiting on it.
    private func prewarm() {
        let context = Settings.shared.context
        DispatchQueue.global(qos: .utility).async { [weak self] in
            OperationCatalog.prewarm(context: context)
            DispatchQueue.main.async {
                self?.wheel.prewarm()
                self?.runner.prewarm()
            }
        }
    }

    /// "Open With" from Finder, or files dropped on the app icon.
    func application(_ application: NSApplication, open urls: [URL]) {
        showKeyboardWheel(for: urls)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow.show()
        return true
    }

    private func showKeyboardWheel(for urls: [URL]) {
        guard !urls.isEmpty else { return }
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        let point = screen.map { NSPoint(x: $0.visibleFrame.midX, y: $0.visibleFrame.midY) } ?? NSEvent.mouseLocation
        wheel.show(urls: urls, wheel: .convert, at: point, keyboard: true)
    }

    @objc private func convertFinderSelection() {
        let urls = FinderSelection.urls()
        if urls.isEmpty {
            NSSound.beep()
            return
        }
        showKeyboardWheel(for: urls)
    }

    @objc private func stopAll() {
        runner.stopAll()
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }

    @objc private func openRepository() {
        NSWorkspace.shared.open(AppInfo.repository)
    }

    /// Spins the menu bar slice while something is converting.
    private func setSpinning(_ spinning: Bool) {
        spinTimer?.invalidate()
        spinTimer = nil
        guard spinning, !Motion.reduced else {
            statusItem?.button?.image = Glyphs.menuBarIcon()
            return
        }
        let frames = (0..<6).map { Glyphs.menuBarIcon(lit: $0) }
        var frame = 1
        spinTimer = Timer.scheduledTimer(withTimeInterval: 0.11, repeats: true) { [weak self] _ in
            frame = (frame + 1) % frames.count
            self?.statusItem?.button?.image = frames[frame]
        }
        // Lets macOS line the ticks up with other wake-ups instead of waking just for the icon.
        spinTimer?.tolerance = 0.02
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = Glyphs.menuBarIcon()
        item.button?.toolTip = AppInfo.name

        let menu = NSMenu()
        let hint = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        hintItem = hint
        menu.delegate = self
        menu.addItem(.separator())

        let convert = NSMenuItem(title: "Convert Finder Selection", action: #selector(convertFinderSelection), keyEquivalent: "c")
        convert.keyEquivalentModifierMask = [.control, .option]
        convert.target = self
        menu.addItem(convert)

        let stop = NSMenuItem(title: "Stop Converting", action: #selector(stopAll), keyEquivalent: ".")
        stop.target = self
        stop.isHidden = true
        menu.addItem(stop)
        stopItem = stop

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let source = NSMenuItem(title: "Source Code", action: #selector(openRepository), keyEquivalent: "")
        source.target = self
        menu.addItem(source)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit \(AppInfo.name)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }
}

extension AppDelegate: NSMenuDelegate {
    /// Names the Convert key as it is now, since it can change in Settings after launch.
    func menuWillOpen(_ menu: NSMenu) {
        hintItem?.title = "Drag a file and hold \(Settings.shared.convertKey.glyph)"
    }
}

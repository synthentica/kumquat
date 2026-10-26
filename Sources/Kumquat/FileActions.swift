import AppKit
import KumquatCore
import Quartz

/// The Actions wheel: things to do with files that aren't conversions.
enum FileActions {
    static func operations(for urls: [URL]) -> [FileOperation] {
        guard !urls.isEmpty else { return [] }
        var ops: [FileOperation] = [
            action("airdrop", "AirDrop", "dot.radiowaves.left.and.right") { urls in
                NSApp.activate(ignoringOtherApps: true)
                guard let service = NSSharingService(named: .sendViaAirDrop), service.canPerform(withItems: urls) else {
                    throw OperationError.failed("AirDrop isn't available right now.")
                }
                service.perform(withItems: urls)
                return OperationOutcome(silent: true)
            },
        ]
        if urls.count == 1 {
            ops.append(action("float", "Float", "pip") { urls in
                FloatingPreview.show(urls[0])
                return OperationOutcome(silent: true)
            })
        }
        ops += [
            action("copy", "Copy", "doc.on.doc") { urls in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects(urls as [NSURL])
                return OperationOutcome(message: urls.count == 1 ? "Copied \(urls[0].lastPathComponent)" : "Copied \(urls.count) items")
            },
            action("path", "Copy Path", "link") { urls in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(urls.map(\.path).joined(separator: "\n"), forType: .string)
                return OperationOutcome(message: urls.count == 1 ? urls[0].path : "Copied \(urls.count) paths")
            },
            action("terminal", "Terminal", "terminal") { urls in
                let folder = urls[0].isDirectory ? urls[0] : urls[0].deletingLastPathComponent()
                guard let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else {
                    throw OperationError.failed("Terminal wasn't found.")
                }
                NSWorkspace.shared.open([folder], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
                return OperationOutcome(silent: true)
            },
            action("move", "Move to…", "folder") { urls in
                NSApp.activate(ignoringOtherApps: true)
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.canCreateDirectories = true
                panel.prompt = "Move Here"
                panel.message = urls.count == 1 ? "Move \(urls[0].lastPathComponent) to…" : "Move \(urls.count) items to…"
                guard panel.runModal() == .OK, let folder = panel.url else { return OperationOutcome(silent: true) }
                // Every name is checked before anything moves, so a clash halfway through doesn't leave the items
                // split between two folders.
                var names = Set<String>()
                for url in urls {
                    let name = url.lastPathComponent
                    guard names.insert(name).inserted,
                          !FileManager.default.fileExists(atPath: folder.appendingPathComponent(name).path)
                    else { throw OperationError.failed("\(name) already exists there.") }
                }
                var moved: [URL] = []
                for url in urls {
                    let target = folder.appendingPathComponent(url.lastPathComponent)
                    try FileManager.default.moveItem(at: url, to: target)
                    moved.append(target)
                }
                return OperationOutcome(outputs: moved, message: moved.count == 1 ? "Moved \(moved[0].lastPathComponent)" : "Moved \(moved.count) items")
            },
        ]
        return ops
    }

    private static func action(_ id: String, _ title: String, _ symbol: String, _ body: @escaping @MainActor ([URL]) throws -> OperationOutcome) -> FileOperation {
        FileOperation(id: "actions.\(id)", title: title, symbol: symbol, wheel: .actions, verb: title) { urls, _ in
            try await MainActor.run { try body(urls) }
        }
    }
}

/// A small always-on-top Quick Look window, handy for keeping a reference image in view.
enum FloatingPreview {
    private static var windows: [NSPanel] = []

    static func show(_ url: URL) {
        let size = previewSize(for: url)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = url.lastPathComponent
        panel.titlebarAppearsTransparent = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        if let preview = QLPreviewView(frame: NSRect(origin: .zero, size: size), style: .normal) {
            preview.autoresizingMask = [.width, .height]
            preview.previewItem = url as NSURL
            panel.contentView = preview
        }
        let mouse = NSEvent.mouseLocation
        panel.setFrameOrigin(NSPoint(x: mouse.x - size.width / 2, y: mouse.y - size.height / 2))
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: panel, queue: .main) { note in
            windows.removeAll { $0 === note.object as? NSPanel }
        }
        windows.append(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private static func previewSize(for url: URL) -> NSSize {
        if let image = NSImage(contentsOf: url), image.size.width > 0, image.size.height > 0 {
            let scale = min(1, 520 / max(image.size.width, image.size.height))
            return NSSize(width: max(200, image.size.width * scale), height: max(160, image.size.height * scale))
        }
        return NSSize(width: 480, height: 360)
    }
}

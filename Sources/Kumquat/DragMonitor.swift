import AppKit
import KumquatCore

/// Notices when the user drags files anywhere on screen and presses a wheel modifier.
///
/// Uses global mouse monitors (no Accessibility permission needed) and the drag pasteboard's
/// change count to tell file drags from ordinary mouse drags.
final class DragMonitor {
    var onWheelKey: ((Wheel) -> Void)?
    var onDragEnded: (() -> Void)?

    private var monitors: [Any] = []
    private let pasteboard = NSPasteboard(name: .drag)
    private var changeCountAtMouseDown = 0
    private var isFileDrag = false
    private var activeWheel: Wheel?
    private var timer: Timer?

    func start() {
        guard monitors.isEmpty else { return }
        let handlers: [(NSEvent.EventTypeMask, (NSEvent) -> Void)] = [
            (.leftMouseDown, { [weak self] _ in self?.mouseDown() }),
            (.leftMouseDragged, { [weak self] _ in self?.mouseDragged() }),
            (.leftMouseUp, { [weak self] _ in self?.endDrag() }),
        ]
        for (mask, handler) in handlers {
            if let monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler) {
                monitors.append(monitor)
            }
        }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        endDrag()
    }

    private func mouseDown() {
        changeCountAtMouseDown = pasteboard.changeCount
        isFileDrag = false
    }

    private func mouseDragged() {
        guard !isFileDrag, pasteboard.changeCount != changeCountAtMouseDown else { return }
        guard pasteboard.types?.contains(.fileURL) == true else { return }
        isFileDrag = true
        activeWheel = nil
        // Poll the modifier keys while the drag lasts, so a key pressed with the mouse still is noticed.
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        poll()
    }

    private func poll() {
        guard isFileDrag else { return }
        if NSEvent.pressedMouseButtons & 1 == 0 {
            endDrag()
            return
        }
        guard Settings.shared.dragWheelEnabled else { return }
        if let wheel = Settings.shared.wheel(for: NSEvent.modifierFlags), wheel != activeWheel {
            activeWheel = wheel
            onWheelKey?(wheel)
        }
    }

    private func endDrag() {
        timer?.invalidate()
        timer = nil
        guard isFileDrag else { return }
        isFileDrag = false
        activeWheel = nil
        onDragEnded?()
    }

    /// File URLs being dragged right now, if the drag pasteboard can tell.
    func draggedURLs() -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        return (pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL]) ?? []
    }
}

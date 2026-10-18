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
    /// Drag events left before an ordinary drag (a selection, a window, a slider) stops being checked.
    private var checksLeft = 0
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
        checksLeft = 24
    }

    /// Runs for every mouse movement with the button down, anywhere on screen, so it gives up quickly:
    /// a file drag fills the drag pasteboard within its first few events, and any other drag
    /// is left alone after that instead of asking the pasteboard server on every event.
    private func mouseDragged() {
        guard !isFileDrag, checksLeft > 0 else { return }
        checksLeft -= 1
        guard pasteboard.changeCount != changeCountAtMouseDown else { return }
        checksLeft = 0
        guard pasteboard.types?.contains(.fileURL) == true else { return }
        isFileDrag = true
        activeWheel = nil
        // Poll the modifier keys while the drag lasts, so a key pressed with the mouse still is noticed.
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.poll() }
        timer.tolerance = 1.0 / 240
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

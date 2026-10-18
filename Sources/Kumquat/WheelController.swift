import AppKit
import KumquatCore
import SwiftUI

final class WheelModel: ObservableObject {
    @Published var urls: [URL] = []
    @Published var wheel: Wheel = .convert
    @Published var operations: [FileOperation] = []
    @Published var highlighted: Int?
    @Published var isKeyboardMode = false
    @Published var isShown = false
    /// 0 → 1 while the wheel opens: the disc, hub and hint bar pop in.
    @Published var appear: Double = 1
    /// 0 → 1 each time a wheel's segments bloom out of the hub, on opening and on switching wheels.
    @Published var bloom: Double = 1
    /// Angles of the light on the rind, which follows the highlighted segment.
    @Published var indicatorStart: Double = 0
    @Published var indicatorEnd: Double = 0
    /// The segment a file was just dropped on, which flashes as the wheel closes.
    @Published var pressed: Int?
    /// Scale the wheel grows from when opening, and shrinks or swells to when closing.
    @Published var exitScale: CGFloat = 0.9
    /// Offscreen rendering can't show live blur, so previews use solid glass instead.
    var isPreview = false
    /// Lets the preview renderer draw the frames between two highlighted segments.
    var liftOverride: [Int: Double]?

    var layout: WheelLayout { WheelLayout(count: operations.count) }

    var highlightedOperation: FileOperation? {
        highlighted.flatMap { operations.indices.contains($0) ? operations[$0] : nil }
    }
}

/// Shows the wheel, tracks what is under the pointer, and hands the chosen operation to the runner.
final class WheelController {
    let model = WheelModel()
    var onPerform: ((FileOperation, [URL]) -> Void)?
    private lazy var panel = WheelPanel(controller: self)
    private var hideWork: DispatchWorkItem?

    var isVisible: Bool { panel.isVisible && model.isShown }

    func show(urls: [URL], wheel: Wheel, at point: NSPoint, keyboard: Bool) {
        hideWork?.cancel()
        withoutAnimation {
            model.isShown = false
            model.exitScale = 0.9
            model.pressed = nil
            model.isKeyboardMode = keyboard
            model.urls = urls
            model.wheel = wheel
            model.highlighted = nil
            reloadOperations()
        }
        if keyboard, !model.operations.isEmpty { highlight(0) }

        panel.position(wheelCenter: point)
        if keyboard {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            panel.makeFirstResponder(panel.container)
        } else {
            panel.orderFrontRegardless()
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) { model.isShown = true }
        playBloom(appearing: true)
    }

    /// Builds the panel and draws the wheel once, invisibly, so the first real opening is as quick as the rest.
    func prewarm() {
        guard !panel.isVisible else { return }
        withoutAnimation {
            model.urls = [URL(fileURLWithPath: "/kumquat-prewarm.png")]
            model.wheel = .convert
            reloadOperations()
        }
        panel.alphaValue = 0
        panel.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
        panel.orderFrontRegardless()
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.contentView?.displayIfNeeded()
        panel.orderOut(nil)
        panel.alphaValue = 1
        withoutAnimation {
            model.urls = []
            model.operations = []
        }
    }

    func switchTo(_ wheel: Wheel) {
        guard wheel != model.wheel else { return }
        withAnimation(Motion.switchWheel) {
            model.wheel = wheel
            model.highlighted = nil
            reloadOperations()
        }
        playBloom(appearing: false)
        if model.isKeyboardMode, !model.operations.isEmpty { highlight(0) }
    }

    /// Restarts the opening choreography from the first frame.
    private func playBloom(appearing: Bool) {
        guard !Motion.reduced else {
            withoutAnimation {
                model.bloom = 1
                model.appear = 1
            }
            return
        }
        withoutAnimation {
            model.bloom = 0
            if appearing { model.appear = 0 }
        }
        // On the next pass of the run loop, so SwiftUI sees the reset before it animates.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            withAnimation(.linear(duration: Motion.bloomDuration)) { self.model.bloom = 1 }
            if appearing {
                withAnimation(.linear(duration: Motion.appearDuration)) { self.model.appear = 1 }
            }
        }
    }

    private func withoutAnimation(_ changes: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, changes)
    }

    func cycleWheel(forward: Bool = true) {
        let all = Wheel.allCases
        let index = all.firstIndex(of: model.wheel) ?? 0
        switchTo(all[(index + (forward ? 1 : all.count - 1)) % all.count])
    }

    /// Fills in the dragged files when the drag pasteboard couldn't be read up front.
    func provideURLs(_ urls: [URL]) {
        guard model.urls.isEmpty, !urls.isEmpty else { return }
        model.urls = urls
        reloadOperations()
    }

    func reloadOperations() {
        let urls = model.urls
        if model.wheel == .actions {
            model.operations = FileActions.operations(for: urls)
        } else {
            let all = OperationCatalog.operations(for: urls, wheel: model.wheel, context: Settings.shared.context)
            model.operations = Array(all.prefix(WheelLayout.maxSegments))
        }
    }

    func highlight(_ index: Int?) {
        guard index != model.highlighted else { return }
        if let index, let segment = model.layout.segments.first(where: { $0.index == index }) {
            // Take the short way around the rind.
            let turns = ((model.indicatorStart - segment.start) / 360).rounded()
            let start = segment.start + turns * 360
            let end = start + segment.end - segment.start
            if model.highlighted == nil {
                // Fade in where the pointer is instead of gliding over from the last spot.
                withoutAnimation {
                    model.indicatorStart = start
                    model.indicatorEnd = end
                }
            }
            withAnimation(Motion.highlight) {
                model.highlighted = index
                model.indicatorStart = start
                model.indicatorEnd = end
            }
        } else {
            withAnimation(Motion.highlight) { model.highlighted = nil }
        }
        if index != nil {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }

    func moveHighlight(by delta: Int) {
        let count = model.operations.count
        guard count > 0 else { return }
        let current = model.highlighted ?? (delta > 0 ? -1 : 0)
        highlight(((current + delta) % count + count) % count)
    }

    func perform(index: Int, urls dropped: [URL]? = nil) {
        guard model.operations.indices.contains(index) else { return cancel() }
        let operation = model.operations[index]
        let urls = (dropped?.isEmpty == false ? dropped : nil) ?? model.urls
        withoutAnimation { model.pressed = index }
        hide(absorbing: true)
        guard !urls.isEmpty else { return }
        onPerform?(operation, urls)
    }

    func cancel() {
        hide()
    }

    /// The drag ended somewhere. Wait a moment so a drop on the wheel itself is delivered first.
    func dragEnded() {
        guard !model.isKeyboardMode else { return }
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    /// Closes the wheel. After a drop it swells and fades as if it took the file in; otherwise it shrinks away.
    func hide(absorbing: Bool = false) {
        hideWork?.cancel()
        guard model.isShown else { return }
        let duration = absorbing ? 0.22 : 0.13
        withAnimation(absorbing ? .easeIn(duration: duration) : .easeOut(duration: duration)) {
            model.exitScale = absorbing ? 1.07 : 0.86
            model.pressed = nil
            model.isShown = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.02) { [weak self] in
            guard let self, !self.model.isShown else { return }
            self.panel.orderOut(nil)
            self.withoutAnimation { self.model.highlighted = nil }
        }
    }

    // MARK: Keyboard

    func handleKey(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 36, 76, 49: // return, enter, space
            if let index = model.highlighted { perform(index: index) }
        case 53: // escape
            cancel()
        case 48: // tab
            cycleWheel(forward: !event.modifierFlags.contains(.shift))
        case 124, 125: // right, down
            moveHighlight(by: 1)
        case 123, 126: // left, up
            moveHighlight(by: -1)
        default:
            return false
        }
        return true
    }

    func handleFlags(_ flags: NSEvent.ModifierFlags) {
        if let wheel = Settings.shared.wheel(for: flags) { switchTo(wheel) }
    }
}

// MARK: - Panel

/// A borderless, non-activating panel that floats above everything and accepts file drops.
final class WheelPanel: NSPanel {
    static let size = NSSize(width: WheelLayout.canvas, height: WheelLayout.canvas + 56)
    let container: WheelContainerView

    init(controller: WheelController) {
        container = WheelContainerView(controller: controller)
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true

        let hosting = NSHostingView(rootView: WheelView(model: controller.model))
        hosting.frame = NSRect(origin: .zero, size: Self.size)
        hosting.autoresizingMask = [.width, .height]
        container.frame = hosting.frame
        container.autoresizingMask = [.width, .height]
        let root = NSView(frame: hosting.frame)
        root.addSubview(hosting)
        root.addSubview(container)
        contentView = root
    }

    override var canBecomeKey: Bool { true }

    override func resignKey() {
        super.resignKey()
        if container.controller?.model.isKeyboardMode == true { container.controller?.cancel() }
    }

    /// Centers the wheel on a screen point, kept fully on screen.
    func position(wheelCenter point: NSPoint) {
        let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
        var origin = NSPoint(x: point.x - Self.size.width / 2, y: point.y - (Self.size.height - WheelLayout.canvas / 2))
        if let visible = screen?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX), visible.maxX - Self.size.width)
            origin.y = min(max(origin.y, visible.minY), visible.maxY - Self.size.height)
        }
        setFrameOrigin(origin)
    }
}

/// Transparent layer over the SwiftUI wheel that does all hit testing: drags, clicks and keys.
final class WheelContainerView: NSView {
    weak var controller: WheelController?
    private var trackingArea: NSTrackingArea?

    init(controller: WheelController) {
        self.controller = controller
        super.init(frame: .zero)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { nil }

    private var wheelCenter: NSPoint {
        NSPoint(x: bounds.midX, y: bounds.maxY - WheelLayout.canvas / 2)
    }

    private func segment(at windowPoint: NSPoint) -> Int? {
        let point = convert(windowPoint, from: nil)
        return controller?.model.layout.segment(atX: point.x - wheelCenter.x, y: point.y - wheelCenter.y)
    }

    private func fileURLs(_ info: NSDraggingInfo) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        return (info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL]) ?? []
    }

    // MARK: Dragging destination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        controller?.provideURLs(fileURLs(sender))
        return update(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        update(sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        controller?.highlight(nil)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { true }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let index = segment(at: sender.draggingLocation) else {
            controller?.cancel()
            return false
        }
        controller?.perform(index: index, urls: fileURLs(sender))
        return true
    }

    private func update(_ sender: NSDraggingInfo) -> NSDragOperation {
        let index = segment(at: sender.draggingLocation)
        controller?.highlight(index)
        guard index != nil else { return [] }
        let mask = sender.draggingSourceOperationMask
        return [NSDragOperation.copy, .generic, .link, .move].first { mask.contains($0) } ?? []
    }

    // MARK: Mouse and keyboard

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        guard controller?.model.isKeyboardMode == true else { return }
        if let index = segment(at: event.locationInWindow) { controller?.highlight(index) }
    }

    override func mouseDown(with event: NSEvent) {
        if let index = segment(at: event.locationInWindow) {
            controller?.perform(index: index)
        } else {
            let point = convert(event.locationInWindow, from: nil)
            let distance = hypot(point.x - wheelCenter.x, point.y - wheelCenter.y)
            if distance > WheelLayout.hubRadius { controller?.cancel() }
        }
    }

    override func keyDown(with event: NSEvent) {
        if controller?.handleKey(event) != true { super.keyDown(with: event) }
    }

    override func flagsChanged(with event: NSEvent) {
        controller?.handleFlags(event.modifierFlags)
    }
}

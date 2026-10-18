import AppKit
import KumquatCore
import QuartzCore
import SwiftUI

final class ToastModel: ObservableObject {
    enum State: Equatable {
        case working
        case done
        case failed
        case stopped
    }

    @Published var state: State = .working
    @Published var title = ""
    @Published var detail = ""
    @Published var isShown = false
    /// Bumped on each failure; the toast shakes once per step.
    @Published var shakes = 0
    /// How far the work has come, once the engine can tell. Until then the line sweeps.
    @Published var progress: Double?
}

/// A small glass capsule at the bottom of the screen showing progress and results.
final class ToastController {
    private let model = ToastModel()
    private var onClick: (() -> Void)?
    /// Called with the job's ticket when its stop button is pressed.
    var onStop: ((Int) -> Void)?
    private var hideWork: DispatchWorkItem?
    private var job = 0
    private static let size = NSSize(width: 420, height: 76)

    private lazy var panel: NSPanel = {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        let view = ToastView(model: model, onClick: { [weak self] in
            self?.onClick?()
            self?.hide()
        }, onStop: { [weak self] in
            guard let self else { return }
            self.onStop?(self.job)
        })
        panel.contentView = NSHostingView(rootView: view)
        return panel
    }()

    /// Builds the panel ahead of time, so the first toast appears without a hitch.
    func prewarm() {
        panel.contentView?.layoutSubtreeIfNeeded()
    }

    /// Shows work starting, and returns the ticket its progress updates must carry.
    @discardableResult
    func showProgress(_ title: String, detail: String) -> Int {
        let signpost = Trace.signposter.beginInterval("First feedback", id: Trace.signposter.makeSignpostID())
        job += 1
        model.progress = nil
        show(.working, title, detail, onClick: nil, autoHide: nil)
        // The first sign that the drop worked: get it on screen before the work starts.
        panel.displayIfNeeded()
        CATransaction.flush()
        Trace.signposter.endInterval("First feedback", signpost)
        return job
    }

    /// Moves the progress line for the job shown last. Updates from an older job, or ones arriving
    /// after the result is already up, are dropped.
    func setProgress(_ fraction: Double, job: Int) {
        guard job == self.job, model.state == .working, model.isShown else { return }
        // A change too small to see isn't worth a redraw.
        if let current = model.progress, abs(current - fraction) < 0.004 { return }
        withAnimation(.linear(duration: 0.2)) { model.progress = fraction }
    }

    func showDone(_ title: String, detail: String, onClick: (() -> Void)?) {
        show(.done, title, detail, onClick: onClick, autoHide: 3.2)
    }

    func showFailure(_ title: String, detail: String) {
        show(.failed, title, detail, onClick: nil, autoHide: 5)
    }

    func showStopped(_ title: String, detail: String, onClick: (() -> Void)?) {
        show(.stopped, title, detail, onClick: onClick, autoHide: 3.2)
    }

    private func show(_ state: ToastModel.State, _ title: String, _ detail: String, onClick: (() -> Void)?, autoHide: TimeInterval?) {
        hideWork?.cancel()
        self.onClick = onClick
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let visible = screen?.visibleFrame, !model.isShown {
            panel.setFrameOrigin(NSPoint(x: visible.midX - Self.size.width / 2, y: visible.minY + 22))
        }
        panel.orderFrontRegardless()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            model.state = state
            model.title = title
            model.detail = detail
            model.isShown = true
        }
        if state == .failed, !Motion.reduced {
            withAnimation(.linear(duration: 0.45)) { model.shakes += 1 }
        }
        if let autoHide {
            let work = DispatchWorkItem { [weak self] in self?.hide() }
            hideWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + autoHide, execute: work)
        }
    }

    func hide() {
        hideWork?.cancel()
        withAnimation(.easeIn(duration: 0.2)) { model.isShown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self, !self.model.isShown else { return }
            self.panel.orderOut(nil)
        }
    }
}

private struct ToastView: View {
    @ObservedObject var model: ToastModel
    let onClick: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                switch model.state {
                case .working:
                    Circle().fill(Color.white.opacity(0.1)).frame(width: 30, height: 30)
                    SliceSpinner(size: 22, paused: !model.isShown)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                case .done:
                    StatusBadge(colors: Palette.leaf, drawsCheck: true)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                case .failed:
                    StatusBadge(colors: [Color(hex: 0xFF7A5C), Color(hex: 0xE5484D)], drawsCheck: false)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                case .stopped:
                    StatusBadge(colors: [Color(hex: 0x8E8E93), Color(hex: 0x636366)], drawsCheck: false, symbol: "stop.fill")
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(model.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text(model.detail)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: 300, alignment: .leading)
            .id(model.title)
            .transition(.opacity.combined(with: .offset(y: 6)))
            if model.state == .working {
                Button(action: onStop) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Stop")
                .accessibilityLabel("Stop")
                .transition(.opacity)
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 18)
        .padding(.vertical, 9)
        .background(
            ZStack {
                VisualEffect(material: .hudWindow)
                Palette.glass.opacity(0.35)
            }
            .clipShape(Capsule())
        )
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75))
        .overlay(alignment: .bottom) {
            // A thin rind-colored line that sweeps along the bottom while working.
            if model.state == .working {
                Group {
                    if let progress = model.progress {
                        ProgressFill(fraction: progress)
                    } else {
                        ProgressSweep(paused: !model.isShown)
                    }
                }
                    .frame(height: 2)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 1)
                    .transition(.opacity)
            }
        }
        .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
        .modifier(ShakeEffect(progress: Double(model.shakes)))
        .environment(\.colorScheme, .dark)
        .contentShape(Capsule())
        .onTapGesture(perform: onClick)
        .scaleEffect(model.isShown ? 1 : 0.9)
        .offset(y: model.isShown ? 0 : 28)
        .opacity(model.isShown ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A colored circle that pops in and draws its checkmark, or shows an exclamation mark.
private struct StatusBadge: View {
    let colors: [Color]
    let drawsCheck: Bool
    var symbol = "exclamationmark"
    @State private var drawn: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
                .shadow(color: colors.last?.opacity(0.6) ?? .clear, radius: 6)
            if drawsCheck {
                CheckShape()
                    .trim(from: 0, to: drawn)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
            } else {
                Image(systemName: symbol)
                    .font(.system(size: symbol == "exclamationmark" ? 13 : 11, weight: .heavy))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 30, height: 30)
        .onAppear {
            drawn = 0
            withAnimation(.easeOut(duration: 0.32).delay(0.1)) { drawn = 1 }
        }
    }
}

/// A rind-colored line that fills as the work goes.
private struct ProgressFill: View {
    var fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                Capsule()
                    .fill(LinearGradient(colors: Palette.rind, startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(2, proxy.size.width * fraction))
            }
        }
        .clipShape(Capsule())
    }
}

/// An endless highlight sliding along a track.
private struct ProgressSweep: View {
    var paused = false

    var body: some View {
        // 40 frames a second is smooth for a soft gradient and leaves the GPU alone on 120 Hz screens.
        TimelineView(.animation(minimumInterval: 1.0 / 40, paused: paused)) { timeline in
            let phase = (timeline.date.timeIntervalSinceReferenceDate * 0.9).truncatingRemainder(dividingBy: 1)
            GeometryReader { proxy in
                let width = proxy.size.width
                Capsule()
                    .fill(LinearGradient(colors: [Color.clear] + Palette.rind + [Color.clear], startPoint: .leading, endPoint: .trailing))
                    .frame(width: width * 0.4)
                    .offset(x: -width * 0.4 + (width * 1.4) * CGFloat(phase))
            }
            .clipShape(Capsule())
        }
    }
}

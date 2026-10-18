import AppKit
import SwiftUI

final class ToastModel: ObservableObject {
    enum State: Equatable {
        case working
        case done
        case failed
    }

    @Published var state: State = .working
    @Published var title = ""
    @Published var detail = ""
    @Published var isShown = false
}

/// A small glass capsule at the bottom of the screen showing progress and results.
final class ToastController {
    private let model = ToastModel()
    private var onClick: (() -> Void)?
    private var hideWork: DispatchWorkItem?
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
        let view = ToastView(model: model) { [weak self] in
            self?.onClick?()
            self?.hide()
        }
        panel.contentView = NSHostingView(rootView: view)
        return panel
    }()

    func showProgress(_ title: String, detail: String) {
        show(.working, title, detail, onClick: nil, autoHide: nil)
    }

    func showDone(_ title: String, detail: String, onClick: (() -> Void)?) {
        show(.done, title, detail, onClick: onClick, autoHide: 3.2)
    }

    func showFailure(_ title: String, detail: String) {
        show(.failed, title, detail, onClick: nil, autoHide: 5)
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

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(iconBackground).frame(width: 30, height: 30)
                switch model.state {
                case .working:
                    ProgressView().controlSize(.small).tint(.white)
                case .done:
                    Image(systemName: "checkmark").font(.system(size: 13, weight: .heavy)).foregroundStyle(.white)
                case .failed:
                    Image(systemName: "exclamationmark").font(.system(size: 13, weight: .heavy)).foregroundStyle(.white)
                }
            }
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
        }
        .padding(.leading, 10)
        .padding(.trailing, 18)
        .padding(.vertical, 9)
        .background(VisualEffect(material: .hudWindow).clipShape(Capsule()))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75))
        .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
        .environment(\.colorScheme, .dark)
        .contentShape(Capsule())
        .onTapGesture(perform: onClick)
        .offset(y: model.isShown ? 0 : 24)
        .opacity(model.isShown ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var iconBackground: AnyShapeStyle {
        switch model.state {
        case .working: AnyShapeStyle(Color.white.opacity(0.14))
        case .done: AnyShapeStyle(LinearGradient(colors: [Color(hex: 0x34C77B), Color(hex: 0x1FA463)], startPoint: .top, endPoint: .bottom))
        case .failed: AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFF6B5A), Color(hex: 0xE5484D)], startPoint: .top, endPoint: .bottom))
        }
    }
}

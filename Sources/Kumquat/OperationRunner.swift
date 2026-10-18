import AppKit
import KumquatCore

/// Runs an operation in the background and reports through the toast.
final class OperationRunner {
    private let toast = ToastController()

    func run(_ operation: FileOperation, on urls: [URL]) {
        let settings = Settings.shared
        let context = settings.context
        let subject = urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) items"
        let isAction = operation.wheel == .actions
        if !isAction { toast.showProgress(operation.verb + "…", detail: subject) }
        let started = Date()

        Task.detached(priority: .userInitiated) {
            do {
                let outcome = try await operation.perform(urls, context)
                await MainActor.run { self.finish(outcome, operation: operation, started: started) }
            } catch {
                await MainActor.run {
                    self.toast.showFailure("Couldn't finish", detail: error.localizedDescription)
                    self.playSound(success: false)
                }
            }
        }
    }

    private func finish(_ outcome: OperationOutcome, operation: FileOperation, started: Date) {
        if outcome.silent { return }
        let outputs = outcome.outputs
        if outputs.isEmpty, !outcome.failures.isEmpty {
            toast.showFailure("Couldn't finish", detail: outcome.failures.joined(separator: "\n"))
            playSound(success: false)
            return
        }
        let elapsed = Date().timeIntervalSince(started)
        let time = elapsed < 1 ? String(format: "%.0f ms", elapsed * 1000) : String(format: "%.1f s", elapsed)
        let title = outcome.message ?? (outputs.count == 1 ? outputs[0].lastPathComponent : "\(outputs.count) files ready")
        var detail = operation.wheel == .actions ? "" : "Done in \(time) · click to show in Finder"
        if !outcome.failures.isEmpty {
            detail = "\(outcome.failures.count) failed: " + outcome.failures.joined(separator: ", ")
        }
        toast.showDone(title, detail: detail, onClick: outputs.isEmpty ? nil : {
            NSWorkspace.shared.activateFileViewerSelecting(outputs)
        })
        playSound(success: true)
        if Settings.shared.revealWhenDone, !outputs.isEmpty, operation.wheel != .actions {
            NSWorkspace.shared.activateFileViewerSelecting(outputs)
        }
    }

    private func playSound(success: Bool) {
        guard Settings.shared.playSound else { return }
        NSSound(named: success ? "Pop" : "Basso")?.play()
    }
}

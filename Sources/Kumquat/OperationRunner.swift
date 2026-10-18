import AppKit
import KumquatCore

/// Runs an operation in the background and reports through the toast.
final class OperationRunner {
    private let toast = ToastController()
    /// Called with true when the first operation starts and false when the last one ends.
    var onBusyChanged: ((Bool) -> Void)?
    private var running = 0 {
        didSet {
            if (oldValue == 0) != (running == 0) { onBusyChanged?(running > 0) }
        }
    }
    /// Jobs in flight by their toast ticket, so the toast's stop button and the menu can cancel them.
    private var tasks: [Int: Task<Void, Never>] = [:]

    init() {
        toast.onStop = { [weak self] job in self?.stop(job) }
    }

    func prewarm() {
        toast.prewarm()
    }

    /// Stops one job: its tools are terminated, files not yet started are skipped, and half-written results removed.
    func stop(_ job: Int) {
        tasks[job]?.cancel()
    }

    func stopAll() {
        tasks.values.forEach { $0.cancel() }
    }

    func run(_ operation: FileOperation, on urls: [URL]) {
        let settings = Settings.shared
        let context = settings.context
        let subject = urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) items"
        let isAction = operation.wheel == .actions
        let job = isAction ? 0 : toast.showProgress(operation.verb + "…", detail: subject)
        let started = Date()
        if !isAction { running += 1 }

        let sink: (@Sendable (Double) -> Void)?
        if isAction {
            sink = nil
        } else {
            let relay = ProgressRelay { [weak self] fraction in self?.toast.setProgress(fraction, job: job) }
            sink = { relay.send($0) }
        }
        let task = Task.detached(priority: .userInitiated) {
            let result: Result<OperationOutcome, Error>
            do {
                result = .success(try await WorkProgress.$sink.withValue(sink) {
                    try await Trace.operation(operation.id, files: urls.count) {
                        try await operation.perform(urls, context)
                    }
                })
            } catch {
                result = .failure(error)
            }
            let stopped = Task.isCancelled
            await MainActor.run {
                if !isAction {
                    self.running -= 1
                    self.tasks[job] = nil
                }
                switch result {
                case .success(let outcome) where stopped:
                    self.showStopped(kept: outcome.outputs)
                case .success(let outcome):
                    self.finish(outcome, operation: operation, started: started)
                case .failure where stopped:
                    self.showStopped(kept: [])
                case .failure(let error):
                    self.toast.showFailure("Couldn't finish", detail: error.localizedDescription)
                    self.playSound(success: false)
                }
            }
        }
        if !isAction { tasks[job] = task }
    }

    private func showStopped(kept outputs: [URL]) {
        let detail = switch outputs.count {
        case 0: "Nothing was left half-written."
        case 1: "Kept the file that was already done · click to show"
        default: "Kept the \(outputs.count) files that were already done · click to show"
        }
        toast.showStopped("Stopped", detail: detail, onClick: outputs.isEmpty ? nil : {
            NSWorkspace.shared.activateFileViewerSelecting(outputs)
        })
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

/// Carries progress from the worker threads to the toast about 15 times a second,
/// so a fast loop reporting thousands of steps never floods the main thread.
final class ProgressRelay: @unchecked Sendable {
    private let lock = NSLock()
    private var latest: Double = 0
    private var scheduled = false
    private let deliver: (Double) -> Void

    init(_ deliver: @escaping (Double) -> Void) {
        self.deliver = deliver
    }

    func send(_ fraction: Double) {
        lock.lock()
        latest = fraction
        let schedule = !scheduled
        scheduled = true
        lock.unlock()
        guard schedule else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 / 15) { [self] in
            lock.lock()
            let value = latest
            scheduled = false
            lock.unlock()
            deliver(value)
        }
    }
}

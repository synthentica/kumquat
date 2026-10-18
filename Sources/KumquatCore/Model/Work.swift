import Foundation

/// How far the running operation has come, reported from anywhere inside it without passing a handle around.
public enum WorkProgress {
    /// Receives fractions from 0 to 1. Set by whoever shows the progress; engines only call `report`.
    @TaskLocal public static var sink: (@Sendable (Double) -> Void)?

    static func report(_ fraction: Double) {
        sink?(min(max(fraction, 0), 1))
    }

    /// Runs one step of a longer job, mapping its 0…1 onto `start`…`end` of the whole.
    static func stage<T>(_ start: Double, _ end: Double, _ body: () async throws -> T) async rethrows -> T {
        guard let outer = sink else { return try await body() }
        return try await $sink.withValue({ outer(start + (end - start) * $0) }, operation: body)
    }

    /// Reports `done` out of `total` steps.
    static func report(_ done: Int, of total: Int) {
        guard total > 0 else { return }
        report(Double(done) / Double(total))
    }
}

/// Adds up the progress of files running side by side into one fraction for the whole batch.
final class BatchProgress: @unchecked Sendable {
    private let lock = NSLock()
    private var fractions: [Double]
    private let sink: (@Sendable (Double) -> Void)?

    init(count: Int, sink: (@Sendable (Double) -> Void)?) {
        fractions = Array(repeating: 0, count: count)
        self.sink = sink
    }

    func set(_ index: Int, _ fraction: Double) {
        guard let sink else { return }
        lock.lock()
        defer { lock.unlock() }
        // Progress only moves forward, even when an engine retries a file another way.
        fractions[index] = max(fractions[index], fraction)
        // Reported while still locked, so totals from parallel files arrive in order.
        sink(fractions.reduce(0, +) / Double(fractions.count))
    }
}

/// Caps how many jobs of one kind run at once, across every operation in flight.
///
/// Image and audio work scales with cores, but each video encode already uses the whole machine
/// (or one of the few hardware encoders), and Keynote, Pages and Numbers take one document at a time.
/// Running more than that at once only adds memory and heat.
public final class Lane: @unchecked Sendable {
    /// Video encodes, by FFmpeg or AVFoundation.
    public static let encoder = Lane(limit: min(2, max(1, ProcessInfo.processInfo.activeProcessorCount / 4)))
    /// LibreOffice and the iWork apps.
    public static let office = Lane(limit: 1)
    /// No cap, for code paths that only sometimes need one.
    static let unlimited = Lane(limit: .max)

    private let limit: Int
    private let lock = NSLock()
    private var active = 0
    private var waiting: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        self.limit = max(1, limit)
    }

    public func run<T>(_ body: () async throws -> T) async throws -> T {
        await acquire()
        defer { release() }
        return try await body()
    }

    private func acquire() async {
        await withCheckedContinuation { continuation in enter(continuation) }
    }

    /// Takes a free slot right away, or queues until `release` hands one over.
    private func enter(_ continuation: CheckedContinuation<Void, Never>) {
        lock.lock()
        if active < limit {
            active += 1
            lock.unlock()
            continuation.resume()
        } else {
            waiting.append(continuation)
            lock.unlock()
        }
    }

    private func release() {
        lock.lock()
        if waiting.isEmpty {
            active -= 1
            lock.unlock()
        } else {
            // Hand the slot straight to the next job, so `active` stays the same.
            let next = waiting.removeFirst()
            lock.unlock()
            next.resume()
        }
    }
}

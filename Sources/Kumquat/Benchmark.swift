import AppKit
import KumquatCore

/// `Kumquat --benchmark <report.json> [--strict]` measures the app against its budgets
/// (Sources/KumquatCore/Benchmark/Budget.swift) with the real wheel and toast on screen,
/// prints a table and writes the numbers as JSON. scripts/profile.sh runs it under Instruments.
/// With `--strict` it exits with status 1 when a budget is missed.
enum Benchmark {
    static func run(report path: String, strict: Bool) -> Never {
        NSApp.setActivationPolicy(.accessory)
        NSApp.finishLaunching()
        var results: [BudgetResult] = []
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("Kumquat-benchmark-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }

        // The same start-up as the app: lookups cached, wheel and toast built.
        let wheel = WheelController()
        let toast = ToastController()
        OperationCatalog.prewarm(context: Settings.shared.context)
        wheel.prewarm()
        toast.prewarm()
        spin(0.5)

        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let center = NSPoint(x: screen.midX, y: screen.midY)
        let photo = work.appendingPathComponent("Holiday photo.heic")
        FileManager.default.createFile(atPath: photo.path, contents: Data())

        var opens: [Double] = []
        for index in 0..<30 {
            wheel.show(urls: [photo], wheel: Wheel.allCases[index % 3], at: center, keyboard: false)
            opens.append(wheel.lastOpenDuration * 1000)
            spin(0.45)
            wheel.hide()
            spin(0.25)
        }
        results.append(BudgetResult(.wheelOpenFirst, opens[0]))
        results.append(BudgetResult(.wheelOpenMedian, Stats.median(opens)))
        results.append(BudgetResult(.wheelOpenP95, Stats.percentile(opens, 0.95)))

        var feedback: [Double] = []
        for _ in 0..<15 {
            let start = DispatchTime.now().uptimeNanoseconds
            toast.showProgress("Converting to JPEG…", detail: photo.lastPathComponent)
            feedback.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6)
            spin(0.3)
            toast.hide()
            spin(0.35)
        }
        results.append(BudgetResult(.firstFeedbackP95, Stats.percentile(feedback, 0.95)))

        // Idle: nothing on screen, nobody dragging. Settle first, then count processor time for 10 seconds.
        spin(2)
        let cpuBefore = ProcessStats.cpuSeconds()
        let threadsBefore = ProcessStats.threads()
        let idleStart = Date()
        spin(10)
        let idleSeconds = Date().timeIntervalSince(idleStart)
        let idleCPU = (ProcessStats.cpuSeconds() - cpuBefore) / idleSeconds * 100
        results.append(BudgetResult(.idleCPU, idleCPU))
        // Which threads were awake, so a miss points at its cause.
        busyThreads = ProcessStats.threads().compactMap { id, now -> (String, Double)? in
            let used = now.seconds - (threadsBefore[id]?.seconds ?? 0)
            return used > 0.0005 ? (now.name, used / idleSeconds * 100) : nil
        }.sorted { $0.1 > $1.1 }
        results.append(BudgetResult(.idleMemory, ProcessStats.memoryFootprintMB()))

        do {
            results += try wait { try await ConversionBenchmark.run(in: work) }
        } catch {
            print("Conversion benchmark failed: \(error.localizedDescription)")
        }

        report(results, to: path)
        exit(strict && results.contains { !$0.pass } ? 1 : 0)
    }

    /// Threads that used the processor while the app was idle, with their share in percent.
    private static var busyThreads: [(String, Double)] = []

    private static func report(_ results: [BudgetResult], to path: String) {
        print("")
        if !busyThreads.isEmpty {
            print("Awake while idle: " + busyThreads.prefix(6).map { "\($0.0) \(String(format: "%.2f", $0.1)) %" }.joined(separator: ", "))
        }
        for result in results {
            let mark = result.pass ? "pass" : "MISS"
            let value = String(format: "%.2f", result.value)
            print("\(mark)  \(result.title): \(value) \(result.unit) (budget \(String(format: "%g", result.limit)) \(result.unit))")
        }
        let passed = results.filter(\.pass).count
        print("\n\(passed) of \(results.count) budgets met")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let machine = ProcessInfo.processInfo
        let document: [String: Any] = [
            "results": (try? JSONSerialization.jsonObject(with: encoder.encode(results))) ?? [],
            "machine": [
                "os": machine.operatingSystemVersionString,
                "cores": machine.activeProcessorCount,
                "memory_gb": Double(machine.physicalMemory) / 1_073_741_824,
                "arch": architecture,
            ],
            "date": ISO8601DateFormatter().string(from: Date()),
            "idle_threads": busyThreads.prefix(10).map { ["name": $0.0, "percent": ($0.1 * 100).rounded() / 100] },
        ]
        if let data = try? JSONSerialization.data(withJSONObject: document, options: [.prettyPrinted, .sortedKeys]) {
            let url = URL(fileURLWithPath: path)
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: url)
        }
    }

    private static var architecture: String {
        #if arch(arm64)
        "arm64"
        #else
        "x86_64"
        #endif
    }

    /// Lets the run loop draw and animate for a while.
    private static func spin(_ seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    /// Runs async work from this synchronous, main-thread benchmark while the run loop keeps going.
    private static func wait<T>(_ work: @escaping @Sendable () async throws -> T) throws -> T {
        let box = ResultBox<T>()
        Task.detached { box.set(await Result(async: work)) }
        while box.value == nil { spin(0.01) }
        return try box.value!.get()
    }
}

private final class ResultBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Result<T, Error>?

    var value: Result<T, Error>? {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func set(_ result: Result<T, Error>) {
        lock.lock()
        stored = result
        lock.unlock()
    }
}

private extension Result where Failure == Error {
    init(async body: () async throws -> Success) async {
        do { self = .success(try await body()) } catch { self = .failure(error) }
    }
}

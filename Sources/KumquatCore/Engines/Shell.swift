import Foundation

/// Runs the command-line tools that ship with macOS (ditto, zip, tar) and FFmpeg.
enum Shell {
    @discardableResult
    static func run(
        _ executable: String,
        _ arguments: [String],
        in directory: URL? = nil,
        environment: [String: String] = [:],
        standardOutput: URL? = nil,
        onOutputLine: (@Sendable (String) -> Void)? = nil
    ) async throws -> String {
        let running = RunningProcess()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                DispatchQueue.global(qos: .userInitiated).async {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: executable)
                    process.arguments = arguments
                    if let directory { process.currentDirectoryURL = directory }
                    if !environment.isEmpty {
                        process.environment = ProcessInfo.processInfo.environment.merging(environment) { $1 }
                    }
                    let errorPipe = Pipe()
                    process.standardError = errorPipe
                    process.standardInput = FileHandle.nullDevice
                    var outputHandle: FileHandle?
                    if let standardOutput {
                        FileManager.default.createFile(atPath: standardOutput.path, contents: nil)
                        outputHandle = try? FileHandle(forWritingTo: standardOutput)
                        process.standardOutput = outputHandle
                    } else if let onOutputLine {
                        let pipe = Pipe()
                        let lines = LineSplitter(onOutputLine)
                        pipe.fileHandleForReading.readabilityHandler = { handle in
                            let data = handle.availableData
                            // An empty read means the tool closed its output; stop being called.
                            if data.isEmpty { handle.readabilityHandler = nil } else { lines.append(data) }
                        }
                        process.standardOutput = pipe
                    } else {
                        process.standardOutput = FileHandle.nullDevice
                    }
                    do {
                        try running.start(process)
                    } catch {
                        continuation.resume(throwing: error)
                        return
                    }
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    try? outputHandle?.close()
                    (process.standardOutput as? Pipe)?.fileHandleForReading.readabilityHandler = nil
                    let message = String(decoding: errorData, as: UTF8.self)
                    if running.wasStopped {
                        continuation.resume(throwing: CancellationError())
                    } else if process.terminationStatus == 0 {
                        continuation.resume(returning: message)
                    } else {
                        let name = URL(fileURLWithPath: executable).lastPathComponent
                        let lastLine = message
                            .split(whereSeparator: \.isNewline)
                            .last.map(String.init) ?? ""
                        continuation.resume(throwing: OperationError.toolFailed(name: name, message: lastLine))
                    }
                }
            }
        } onCancel: {
            running.stop()
        }
    }
}

/// The tool a cancelled task should stop: it is terminated at once, or never started if the cancel came first.
private final class RunningProcess: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var stopped = false

    var wasStopped: Bool {
        lock.lock()
        defer { lock.unlock() }
        return stopped
    }

    func start(_ process: Process) throws {
        lock.lock()
        defer { lock.unlock() }
        if stopped { throw CancellationError() }
        try process.run()
        self.process = process
    }

    func stop() {
        lock.lock()
        stopped = true
        let process = self.process
        lock.unlock()
        if let process, process.isRunning { process.terminate() }
    }
}

/// Turns chunks of a tool's output into whole lines.
private final class LineSplitter: @unchecked Sendable {
    private var buffer = Data()
    private let onLine: @Sendable (String) -> Void

    init(_ onLine: @escaping @Sendable (String) -> Void) {
        self.onLine = onLine
    }

    /// Called on the pipe's own queue, one chunk at a time.
    func append(_ data: Data) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            onLine(String(decoding: buffer[buffer.startIndex..<newline], as: UTF8.self))
            buffer.removeSubrange(buffer.startIndex...newline)
        }
    }
}

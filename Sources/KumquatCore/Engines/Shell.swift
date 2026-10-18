import Foundation

/// Runs the command-line tools that ship with macOS (ditto, zip, tar) and FFmpeg.
enum Shell {
    @discardableResult
    static func run(
        _ executable: String,
        _ arguments: [String],
        in directory: URL? = nil,
        environment: [String: String] = [:],
        standardOutput: URL? = nil
    ) async throws -> String {
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
                } else {
                    process.standardOutput = FileHandle.nullDevice
                }
                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                try? outputHandle?.close()
                let message = String(decoding: errorData, as: UTF8.self)
                if process.terminationStatus == 0 {
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
    }
}

import Darwin
import Foundation
import os

/// Signposts for Instruments: the wheel opening, feedback appearing and every operation show up as
/// intervals under Points of Interest, so a trace says exactly where the time went.
public enum Trace {
    public static let signposter = OSSignposter(subsystem: "com.synthentica.kumquat", category: .pointsOfInterest)

    /// Times one operation on a set of files, named by the operation's id.
    public static func operation<T>(_ id: String, files: Int, _ body: () async throws -> T) async rethrows -> T {
        let state = signposter.beginInterval("Operation", id: signposter.makeSignpostID(), "\(id, privacy: .public) on \(files) files")
        defer { signposter.endInterval("Operation", state) }
        return try await body()
    }
}

/// What the process costs the Mac, read from the kernel the same way Activity Monitor does.
public enum ProcessStats {
    /// The memory footprint Activity Monitor shows in its Memory column, in megabytes.
    public static func memoryFootprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.phys_footprint) / 1_048_576
    }

    /// Processor time this process has used so far, user and system together, in seconds.
    public static func cpuSeconds() -> Double {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        func seconds(_ time: timeval) -> Double { Double(time.tv_sec) + Double(time.tv_usec) / 1_000_000 }
        return seconds(usage.ru_utime) + seconds(usage.ru_stime)
    }
}

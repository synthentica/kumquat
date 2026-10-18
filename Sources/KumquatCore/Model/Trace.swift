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

    /// Processor seconds used by each thread so far, keyed by thread id, with the thread's name.
    /// Two snapshots show which thread is busy when the app should be asleep.
    public static func threads() -> [UInt64: (name: String, seconds: Double)] {
        var list: thread_act_array_t?
        var count: mach_msg_type_number_t = 0
        guard task_threads(mach_task_self_, &list, &count) == KERN_SUCCESS, let list else { return [:] }
        defer {
            for index in 0..<Int(count) { mach_port_deallocate(mach_task_self_, list[index]) }
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: list)), vm_size_t(Int(count) * MemoryLayout<thread_t>.stride))
        }
        var result: [UInt64: (name: String, seconds: Double)] = [:]
        for index in 0..<Int(count) {
            let thread = list[index]
            var identifier = thread_identifier_info_data_t()
            var identifierCount = mach_msg_type_number_t(MemoryLayout<thread_identifier_info_data_t>.size / MemoryLayout<natural_t>.size)
            var extended = thread_extended_info_data_t()
            var extendedCount = mach_msg_type_number_t(MemoryLayout<thread_extended_info_data_t>.size / MemoryLayout<natural_t>.size)
            let gotIdentifier = withUnsafeMutablePointer(to: &identifier) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(identifierCount)) {
                    thread_info(thread, thread_flavor_t(THREAD_IDENTIFIER_INFO), $0, &identifierCount)
                }
            }
            let gotExtended = withUnsafeMutablePointer(to: &extended) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(extendedCount)) {
                    thread_info(thread, thread_flavor_t(THREAD_EXTENDED_INFO), $0, &extendedCount)
                }
            }
            guard gotIdentifier == KERN_SUCCESS, gotExtended == KERN_SUCCESS else { continue }
            let name = withUnsafeBytes(of: extended.pth_name) { bytes in
                String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
            }
            let seconds = Double(extended.pth_user_time + extended.pth_system_time) / 1e9
            result[identifier.thread_id] = (name.isEmpty ? (index == 0 ? "main" : "thread \(index)") : name, seconds)
        }
        return result
    }

    /// Processor time this process has used so far, user and system together, in seconds.
    public static func cpuSeconds() -> Double {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        func seconds(_ time: timeval) -> Double { Double(time.tv_sec) + Double(time.tv_usec) / 1_000_000 }
        return seconds(usage.ru_utime) + seconds(usage.ru_stime)
    }
}

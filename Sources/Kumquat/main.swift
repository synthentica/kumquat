import AppKit

let app = NSApplication.shared

if let flag = CommandLine.arguments.firstIndex(of: "--render-previews") {
    let folder = CommandLine.arguments.indices.contains(flag + 1) ? CommandLine.arguments[flag + 1] : "previews"
    PreviewRenderer.render(into: folder)
    exit(0)
}

if let flag = CommandLine.arguments.firstIndex(of: "--benchmark") {
    let report = CommandLine.arguments.indices.contains(flag + 1) ? CommandLine.arguments[flag + 1] : "benchmark.json"
    Benchmark.run(report: report, strict: CommandLine.arguments.contains("--strict"))
}

if let flag = CommandLine.arguments.firstIndex(of: "--corpus") {
    CorpusRunner.run(arguments: Array(CommandLine.arguments.dropFirst(flag + 1)))
}

let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

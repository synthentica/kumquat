import AppKit
import KumquatCore
import ServiceManagement

enum AppInfo {
    static let name = "Kumquat"
    static let repository = URL(string: "https://github.com/synthentica/converter")!
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}

enum ModifierKey: String, CaseIterable, Identifiable {
    case shift, command, control, option

    var id: String { rawValue }

    var flag: NSEvent.ModifierFlags {
        switch self {
        case .shift: .shift
        case .command: .command
        case .control: .control
        case .option: .option
        }
    }

    var glyph: String {
        switch self {
        case .shift: "⇧"
        case .command: "⌘"
        case .control: "⌃"
        case .option: "⌥"
        }
    }

    var name: String {
        switch self {
        case .shift: "Shift"
        case .command: "Command"
        case .control: "Control"
        case .option: "Option"
        }
    }
}

enum OutputLocation: String, CaseIterable, Identifiable {
    case original, downloads, desktop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original: "Next to the original"
        case .downloads: "Downloads"
        case .desktop: "Desktop"
        }
    }

    var directory: URL? {
        switch self {
        case .original: nil
        case .downloads: FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        case .desktop: FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        }
    }
}

/// User preferences, persisted in UserDefaults.
final class Settings: ObservableObject {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    @Published var convertKey: ModifierKey { didSet { save(convertKey.rawValue, "convertKey") } }
    @Published var toolsKey: ModifierKey { didSet { save(toolsKey.rawValue, "toolsKey") } }
    @Published var actionsKey: ModifierKey { didSet { save(actionsKey.rawValue, "actionsKey") } }
    @Published var output: OutputLocation { didSet { save(output.rawValue, "output") } }
    @Published var revealWhenDone: Bool { didSet { save(revealWhenDone, "revealWhenDone") } }
    @Published var playSound: Bool { didSet { save(playSound, "playSound") } }
    @Published var imageQuality: Double { didSet { save(imageQuality, "imageQuality") } }
    @Published var ffmpegPath: String { didSet { save(ffmpegPath, "ffmpegPath") } }
    @Published var dragWheelEnabled: Bool { didSet { save(dragWheelEnabled, "dragWheelEnabled") } }
    @Published var keepDates: Bool { didSet { save(keepDates, "keepDates") } }

    private init() {
        func key(_ name: String, _ fallback: ModifierKey) -> ModifierKey {
            UserDefaults.standard.string(forKey: name).flatMap(ModifierKey.init(rawValue:)) ?? fallback
        }
        convertKey = key("convertKey", .shift)
        toolsKey = key("toolsKey", .command)
        actionsKey = key("actionsKey", .control)
        output = defaults.string(forKey: "output").flatMap(OutputLocation.init(rawValue:)) ?? .original
        revealWhenDone = defaults.object(forKey: "revealWhenDone") as? Bool ?? false
        playSound = defaults.object(forKey: "playSound") as? Bool ?? true
        imageQuality = defaults.object(forKey: "imageQuality") as? Double ?? 0.85
        ffmpegPath = defaults.string(forKey: "ffmpegPath") ?? ""
        dragWheelEnabled = defaults.object(forKey: "dragWheelEnabled") as? Bool ?? true
        keepDates = defaults.object(forKey: "keepDates") as? Bool ?? true
    }

    private func save(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
    }

    func key(for wheel: Wheel) -> ModifierKey {
        switch wheel {
        case .convert: convertKey
        case .tools: toolsKey
        case .actions: actionsKey
        }
    }

    /// The wheel whose modifier is held, checking Convert first.
    func wheel(for flags: NSEvent.ModifierFlags) -> Wheel? {
        Wheel.allCases.first { flags.contains(key(for: $0).flag) }
    }

    var ffmpeg: URL? { FFmpegEngine.locate(custom: ffmpegPath) }

    var context: OperationContext {
        OperationContext(outputDirectory: output.directory, imageQuality: imageQuality, ffmpeg: ffmpeg, keepsDates: keepDates)
    }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            objectWillChange.send()
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Launch at login: \(error.localizedDescription)")
            }
        }
    }
}

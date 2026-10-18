import AppKit
import Carbon.HIToolbox

/// A system-wide shortcut through Carbon's hot key API, which needs no special permission.
final class HotKey {
    private static var handlers: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var eventHandler: EventHandlerRef?

    private var reference: EventHotKeyRef?
    private let id: UInt32

    init?(keyCode: Int, modifiers: Int, handler: @escaping () -> Void) {
        Self.installHandlerIfNeeded()
        id = Self.nextID
        Self.nextID += 1
        let hotKeyID = EventHotKeyID(signature: OSType(0x4B4D5154), id: id) // "KMQT"
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &reference)
        guard status == noErr else { return nil }
        Self.handlers[id] = handler
    }

    deinit {
        if let reference { UnregisterEventHotKey(reference) }
        Self.handlers[id] = nil
    }

    private static func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
            )
            guard status == noErr else { return status }
            DispatchQueue.main.async { HotKey.handlers[hotKeyID.id]?() }
            return noErr
        }, 1, &type, nil, &eventHandler)
    }
}

enum FinderSelection {
    /// The files selected in the frontmost Finder window (asks for Automation permission once).
    static func urls() -> [URL] {
        let source = """
        tell application "Finder"
            set selectedItems to selection as alias list
        end tell
        set output to ""
        repeat with selectedItem in selectedItems
            set output to output & POSIX path of selectedItem & linefeed
        end repeat
        return output
        """
        var error: NSDictionary?
        guard let result = NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue else { return [] }
        return result.split(separator: "\n").map { URL(fileURLWithPath: String($0)) }
    }
}

import AppKit
import KumquatCore
import SwiftUI

final class SettingsWindowController {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "\(AppInfo.name) Settings"
            window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 520, height: 640))
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @ObservedObject private var settings = Settings.shared
    @State private var ffmpeg = Settings.shared.ffmpeg

    var body: some View {
        Form {
            Section {
                header
            }

            Section("Wheels") {
                keyPicker("Convert", wheel: .convert, selection: $settings.convertKey)
                keyPicker("Tools", wheel: .tools, selection: $settings.toolsKey)
                keyPicker("Actions", wheel: .actions, selection: $settings.actionsKey)
                Toggle("Open the wheel while dragging files", isOn: $settings.dragWheelEnabled)
                LabeledContent("Convert Finder selection") {
                    Text("⌃⌥C").font(.system(.body, design: .rounded).weight(.semibold)).foregroundStyle(.secondary)
                }
            }

            Section("Results") {
                Picker("Save to", selection: $settings.output) {
                    ForEach(OutputLocation.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Show in Finder when done", isOn: $settings.revealWhenDone)
                Toggle("Play a sound", isOn: $settings.playSound)
                LabeledContent("Image quality") {
                    HStack {
                        Slider(value: $settings.imageQuality, in: 0.5...1)
                        Text("\(Int(settings.imageQuality * 100))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }

            Section {
                LabeledContent("FFmpeg") {
                    if let ffmpeg {
                        Label(ffmpeg.path, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text("Not installed").foregroundStyle(.secondary)
                    }
                }
                TextField("Custom path", text: $settings.ffmpegPath, prompt: Text("Found automatically"))
                    .onChange(of: settings.ffmpegPath) { _ in ffmpeg = Settings.shared.ffmpeg }
            } header: {
                Text("More formats")
            } footer: {
                Text("Everything works offline with what's built into macOS. Install FFmpeg (`brew install ffmpeg`) to also get MP3, OGG, Opus, WebM, MKV, AVI and WebP.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Open at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.launchAtLogin = $0 }
                ))
                LabeledContent("Version", value: AppInfo.version)
                Link("Source code on GitHub", destination: AppInfo.repository)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .frame(minHeight: 600)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(AppInfo.name)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("Drag any file and hold \(settings.convertKey.glyph) to convert it. Drop it on a format and you're done.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }

    private func keyPicker(_ title: String, wheel: Wheel, selection: Binding<ModifierKey>) -> some View {
        Picker(selection: selection) {
            ForEach(ModifierKey.allCases) { key in
                Text("\(key.glyph)  \(key.name)").tag(key)
            }
        } label: {
            HStack(spacing: 8) {
                Circle().fill(wheel.gradient).frame(width: 10, height: 10)
                Text(title)
            }
        }
    }
}

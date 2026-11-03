import AppKit
import SwiftUI

struct KeyShortcutRecorder: NSViewRepresentable {
    let value: Binding<String>
    let isRecording: Binding<Bool>

    func makeNSView(context: Context) -> ShortcutRecorderView {
        let view = ShortcutRecorderView()
        view.onShortcutCaptured = { shortcut in
            value.wrappedValue = shortcut
            isRecording.wrappedValue = false
        }
        view.onRecordingChanged = { recording in
            isRecording.wrappedValue = recording
        }
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderView, context: Context) {
        nsView.currentValue = value.wrappedValue
        if isRecording.wrappedValue && !nsView.isFieldRecording {
            nsView.startRecording()
        }
    }
}

final class ShortcutRecorderView: NSView {
    var onShortcutCaptured: ((String) -> Void)?
    var onRecordingChanged: ((Bool) -> Void)?
    var currentValue: String = ""
    var isFieldRecording = false

    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        updateAppearance()

        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .center
        addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
        ])
    }

    private func updateAppearance() {
        if isFieldRecording {
            layer?.borderColor = NSColor.controlAccentColor.cgColor
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor
            label.stringValue = "Gravando..."
            label.textColor = NSColor.controlAccentColor
        } else {
            layer?.borderColor = NSColor.separatorColor.cgColor
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            label.stringValue = currentValue.isEmpty ? "Pressione o atalho..." : currentValue
            label.textColor = currentValue.isEmpty ? NSColor.secondaryLabelColor : NSColor.labelColor
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        if isFieldRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func startRecording() {
        isFieldRecording = true
        window?.makeFirstResponder(self)
        onRecordingChanged?(true)
        updateAppearance()
    }

    func stopRecording() {
        isFieldRecording = false
        onRecordingChanged?(false)
        updateAppearance()
    }

    override func keyDown(with event: NSEvent) {
        guard isFieldRecording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == 53 {
            stopRecording()
            return
        }

        let shortcut = shortcutString(from: event)
        if !shortcut.isEmpty {
            currentValue = shortcut
            onShortcutCaptured?(shortcut)
            stopRecording()
        }
    }

    override func flagsChanged(with event: NSEvent) {
        if isFieldRecording {
            updateAppearance()
        }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 180, height: 26)
    }

    private func shortcutString(from event: NSEvent) -> String {
        var parts: [String] = []

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }

        if let chars = event.charactersIgnoringModifiers?.uppercased(), !chars.isEmpty {
            let keyName = readableKeyName(keyCode: event.keyCode, characters: chars)
            parts.append(keyName)
        }

        return parts.joined()
    }

    private func readableKeyName(keyCode: UInt16, characters: String) -> String {
        switch keyCode {
        case 36: return "↩"
        case 48: return "⇥"
        case 49: return "Space"
        case 51: return "⌫"
        case 53: return "⎋"
        case 76: return "⌤"
        case 117: return "⌦"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 115: return "Home"
        case 119: return "End"
        case 116: return "PgUp"
        case 121: return "PgDn"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default: return characters
        }
    }
}

import AppKit
import SwiftUI

final class ShortcutCapturePicker {
    private static var current: ShortcutCapturePicker?

    static func pickShortcut(completion: @escaping (String) -> Void) {
        current?.cancel()
        let picker = ShortcutCapturePicker(completion: completion)
        current = picker
        picker.begin()
    }

    private let completion: (String) -> Void
    private var panel: NSPanel?
    private let label = NSTextField(labelWithString: "")
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var localMonitor: Any?
    private var finished = false

    private init(completion: @escaping (String) -> Void) {
        self.completion = completion
    }

    private func begin() {
        showPanel()
        if !installEventTap() {
            installLocalMonitor()
        }
    }

    private func showPanel() {
        let width: CGFloat = 420
        let height: CGFloat = 96
        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let win = NSPanel(
            contentRect: NSRect(x: screen.midX - width / 2, y: screen.midY - height / 2 + 120, width: width, height: height),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        win.level = .screenSaver + 1
        win.isOpaque = false
        win.hasShadow = true
        win.backgroundColor = .clear
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let bg = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        bg.material = .hudWindow
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 14
        bg.layer?.masksToBounds = true

        let title = NSTextField(labelWithString: "Pressione o atalho desejado · Esc para cancelar")
        title.font = .systemFont(ofSize: 13, weight: .medium)
        title.textColor = .secondaryLabelColor
        title.alignment = .center
        title.frame = NSRect(x: 12, y: height - 32, width: width - 24, height: 18)

        label.font = .systemFont(ofSize: 28, weight: .semibold)
        label.textColor = .white
        label.alignment = .center
        label.stringValue = "…"
        label.frame = NSRect(x: 12, y: 16, width: width - 24, height: 38)

        bg.addSubview(title)
        bg.addSubview(label)
        win.contentView = bg
        win.orderFrontRegardless()
        panel = win
    }

    private func installEventTap() -> Bool {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue) | CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let picker = Unmanaged<ShortcutCapturePicker>.fromOpaque(refcon).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = picker.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            let code = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags
            DispatchQueue.main.async { picker.handle(type: type, keyCode: code, flags: flags) }
            return type == .keyDown ? nil : Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func installLocalMonitor() {
        NSApp.activate(ignoringOtherApps: true)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            let type: CGEventType = event.type == .keyDown ? .keyDown : .flagsChanged
            self.handle(type: type, keyCode: CGKeyCode(event.keyCode), flags: Self.cgFlags(from: event.modifierFlags))
            return nil
        }
    }

    private static func cgFlags(from flags: NSEvent.ModifierFlags) -> CGEventFlags {
        var result: CGEventFlags = []
        if flags.contains(.command) { result.insert(.maskCommand) }
        if flags.contains(.option) { result.insert(.maskAlternate) }
        if flags.contains(.shift) { result.insert(.maskShift) }
        if flags.contains(.control) { result.insert(.maskControl) }
        return result
    }

    private func handle(type: CGEventType, keyCode: CGKeyCode, flags: CGEventFlags) {
        guard !finished else { return }

        if type == .flagsChanged {
            let symbols = ShortcutKeyMap.modifierSymbols(for: flags)
            label.stringValue = symbols.isEmpty ? "…" : symbols
            return
        }

        if keyCode == 53 && ShortcutKeyMap.modifierSymbols(for: flags).isEmpty {
            cancel()
            return
        }

        let shortcut = ShortcutKeyMap.shortcutString(keyCode: keyCode, flags: flags)
        label.stringValue = shortcut
        finished = true
        teardown()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [self] in
            panel?.orderOut(nil)
            panel = nil
            Self.current = nil
            completion(shortcut)
        }
    }

    private func cancel() {
        finished = true
        teardown()
        panel?.orderOut(nil)
        panel = nil
        Self.current = nil
    }

    private func teardown() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        localMonitor = nil
    }
}

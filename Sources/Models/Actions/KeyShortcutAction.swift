import AppKit
import Foundation

struct KeyShortcutAction: MacroAction {
    private static let modifierKeys: [(flag: CGEventFlags, code: CGKeyCode)] = [
        (.maskControl, 59),
        (.maskAlternate, 58),
        (.maskShift, 56),
        (.maskCommand, 55),
    ]

    func execute(step: MacroStep) async -> Bool {
        guard let (keyCode, flags) = ShortcutKeyMap.parse(step.value) else { return false }

        let source = CGEventSource(stateID: .hidSystemState)
        let active = Self.modifierKeys.filter { flags.contains($0.flag) }

        var held: CGEventFlags = []
        for modifier in active {
            held.insert(modifier.flag)
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: modifier.code, keyDown: true) else { return false }
            event.type = .flagsChanged
            event.flags = held
            event.post(tap: .cghidEventTap)
            try? await Task.sleep(for: .milliseconds(15))
        }

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return false }

        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        try? await Task.sleep(for: .milliseconds(40))
        keyUp.post(tap: .cghidEventTap)
        try? await Task.sleep(for: .milliseconds(15))

        for modifier in active.reversed() {
            held.remove(modifier.flag)
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: modifier.code, keyDown: false) else { continue }
            event.type = .flagsChanged
            event.flags = held
            event.post(tap: .cghidEventTap)
            try? await Task.sleep(for: .milliseconds(15))
        }

        return true
    }
}

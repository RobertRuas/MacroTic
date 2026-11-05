import AppKit
import Foundation

struct TypeTextAction: MacroAction {
    func execute(step: MacroStep) async -> Bool {
        guard !step.value.isEmpty else { return false }
        switch step.textMode {
        case .typing: return await typeCharacters(step.value)
        case .paste: return await paste(step.value)
        }
    }

    private func typeCharacters(_ text: String) async -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)

        for char in text {
            if Task.isCancelled { return false }
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let upEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            else { return false }
            var utf16 = Array(String(char).utf16)
            event.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            upEvent.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            event.post(tap: .cghidEventTap)
            upEvent.post(tap: .cghidEventTap)

            try? await Task.sleep(for: .milliseconds(Int.random(in: 35...90)))
        }
        return true
    }

    private func paste(_ text: String) async -> Bool {
        let pasteboard = NSPasteboard.general
        let previous = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        try? await Task.sleep(for: .milliseconds(80))

        let shortcut = MacroStep.shortcut("⌘V")
        let ok = await KeyShortcutAction().execute(step: shortcut)
        try? await Task.sleep(for: .milliseconds(250))

        if let previous {
            pasteboard.clearContents()
            pasteboard.setString(previous, forType: .string)
        }
        return ok
    }
}

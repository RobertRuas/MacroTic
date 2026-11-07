import AppKit
import ApplicationServices
import Foundation

@Observable
final class ActionRecorder {
    var isRecording = false
    var recordedSteps: [MacroStep] = []
    var elapsedTime: TimeInterval = 0

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var recordingStartTime: Date?
    private var timer: Timer?

    private static var sharedRecorder: ActionRecorder?

    private let specialKeys: Set<CGKeyCode> = [
        36, 48, 51, 53, 76, 96, 97, 98, 99, 100, 101,
        115, 116, 117, 119, 121, 123, 124, 125, 126
    ]

    func startRecording() {
        guard !isRecording else { return }
        recordedSteps = []
        elapsedTime = 0
        isRecording = true
        recordingStartTime = Date()
        ActionRecorder.sharedRecorder = self

        let eventMask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, eventType, event, _ -> Unmanaged<CGEvent>? in
                ActionRecorder.sharedRecorder?.handleEvent(eventType: eventType, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: nil
        )

        guard let tap = eventTap else {
            isRecording = false
            presentPermissionAlert()
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.recordingStartTime else { return }
            self.elapsedTime = Date().timeIntervalSince(start)
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        timer?.invalidate()
        timer = nil

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        ActionRecorder.sharedRecorder = nil
    }

    func makeDraft() -> MacroDraft {
        let draft = MacroDraft()
        draft.name = "Macro Gravada"
        draft.details = "Gravada em \(formattedDate())"
        draft.steps = recordedSteps
        return draft
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: Date())
    }

    private func isPointInOwnWindow(_ cgPoint: CGPoint) -> Bool {
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let cocoaPoint = NSPoint(x: cgPoint.x, y: screenHeight - cgPoint.y)
        return NSApp.windows.contains { $0.isVisible && $0.frame.contains(cocoaPoint) }
    }

    private func handleEvent(eventType: CGEventType, event: CGEvent) {
        if eventType == .leftMouseDown && isPointInOwnWindow(event.location) { return }

        switch eventType {
        case .leftMouseDown:
            let location = event.location
            var step = MacroStep(kind: .click)
            step.clickX = location.x
            step.clickY = location.y
            step.value = "(\(Int(location.x)), \(Int(location.y)))"
            recordedSteps.append(step)

        case .keyDown:
            handleKeyDown(event)

        case .scrollWheel:
            handleScroll(event)

        default:
            break
        }
    }

    private func handleKeyDown(_ event: CGEvent) {
        // Ignore auto-repeat: holding a key must not duplicate a step.
        if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 { return }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        let hasCommand = flags.contains(.maskCommand)
        let hasControl = flags.contains(.maskControl)
        let hasOption = flags.contains(.maskAlternate)
        let isCommandCombo = hasCommand || hasControl || hasOption

        // Backspace while typing edits the typed-text buffer instead of adding a step.
        if keyCode == 51 && !isCommandCombo {
            if let lastIndex = recordedSteps.indices.last,
               recordedSteps[lastIndex].kind == .typeText,
               !recordedSteps[lastIndex].value.isEmpty {
                recordedSteps[lastIndex].value.removeLast()
                if recordedSteps[lastIndex].value.isEmpty {
                    recordedSteps.remove(at: lastIndex)
                }
                return
            }
        }

        let isSpecial = specialKeys.contains(keyCode)

        if isCommandCombo || isSpecial {
            // Build the canonical shortcut string via ShortcutKeyMap (single source of truth),
            // so recorded shortcuts match the picker's format and parse back correctly.
            var step = MacroStep(kind: .keyShortcut)
            step.value = ShortcutKeyMap.shortcutString(keyCode: keyCode, flags: flags)
            recordedSteps.append(step)
        } else {
            // Plain typing (including Shift for capitals/symbols) is coalesced into one step.
            let chars = typedString(for: event)
            guard !chars.isEmpty else { return }
            if let lastIndex = recordedSteps.indices.last,
               recordedSteps[lastIndex].kind == .typeText {
                recordedSteps[lastIndex].value += chars
            } else {
                var step = MacroStep(kind: .typeText)
                step.value = chars
                recordedSteps.append(step)
            }
        }
    }

    private func handleScroll(_ event: CGEvent) {
        let deltaY = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let deltaX = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)

        let direction: ScrollDirection
        let amount: Double

        if abs(deltaY) >= abs(deltaX) {
            direction = deltaY > 0 ? .up : .down
            amount = Double(abs(deltaY))
        } else {
            direction = deltaX > 0 ? .left : .right
            amount = Double(abs(deltaX))
        }

        guard amount > 0 else { return }

        if let lastIndex = recordedSteps.indices.last,
           recordedSteps[lastIndex].kind == .scroll,
           recordedSteps[lastIndex].scrollDirection == direction {
            recordedSteps[lastIndex].scrollAmount = min(recordedSteps[lastIndex].scrollAmount + amount, 50)
            recordedSteps[lastIndex].value = recordedSteps[lastIndex].scrollSummary
        } else {
            var step = MacroStep(kind: .scroll)
            step.scrollDirection = direction
            step.scrollAmount = min(amount, 50)
            step.scrollMovesMouse = true
            step.scrollX = event.location.x
            step.scrollY = event.location.y
            step.value = step.scrollSummary
            recordedSteps.append(step)
        }
    }

    private func typedString(for event: CGEvent) -> String {
        var length = 0
        var chars = [UniChar](repeating: 0, count: 8)
        event.keyboardGetUnicodeString(maxStringLength: 8, actualStringLength: &length, unicodeString: &chars)
        guard length > 0 else { return "" }
        let string = String(utf16CodeUnits: chars, count: length)
        if string.unicodeScalars.contains(where: { $0.value < 0x20 }) { return "" }
        return string
    }

    private func presentPermissionAlert() {
        AppLog.shared.error("Gravação bloqueada: permissão de Acessibilidade não concedida.")
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Permissão de Acessibilidade necessária"
        alert.informativeText = "Para gravar ações, ative o MacroTic em Ajustes do Sistema → Privacidade e Segurança → Acessibilidade."
        alert.runModal()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

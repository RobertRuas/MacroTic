import AppKit
import Foundation

@Observable
final class ActionRecorder {
    var isRecording = false
    var recordedSteps: [MacroStep] = []
    var elapsedTime: TimeInterval = 0

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lastEventTime: Date?
    private var recordingStartTime: Date?
    private var timer: Timer?

    private static var sharedRecorder: ActionRecorder?

    private let specialKeys: Set<CGKeyCode> = [
        36, 48, 49, 51, 53, 76, 96, 97, 98, 99, 100, 101,
        115, 116, 117, 119, 121, 123, 124, 125, 126
    ]

    func startRecording() {
        guard !isRecording else { return }
        recordedSteps = []
        elapsedTime = 0
        isRecording = true
        let now = Date()
        lastEventTime = now
        recordingStartTime = now
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
                return Unmanaged.passRetained(event)
            },
            userInfo: nil
        )

        guard let tap = eventTap else {
            isRecording = false
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

    private func handleEvent(eventType: CGEventType, event: CGEvent) {
        let now = Date()
        if let last = lastEventTime {
            let delay = now.timeIntervalSince(last)
            if delay > 0.3 {
                var delayStep = MacroStep(kind: .delay)
                delayStep.delay = min(delay, 10.0)
                recordedSteps.append(delayStep)
            }
        }
        lastEventTime = now

        switch eventType {
        case .leftMouseDown:
            let location = event.location
            var step = MacroStep(kind: .click)
            step.clickX = location.x
            step.clickY = location.y
            recordedSteps.append(step)

        case .keyDown:
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags
            let keyString = keyNameForCode(keyCode)

            var modifiers: [String] = []
            if flags.contains(.maskCommand) { modifiers.append("⌘") }
            if flags.contains(.maskAlternate) { modifiers.append("⌥") }
            if flags.contains(.maskShift) { modifiers.append("⇧") }
            if flags.contains(.maskControl) { modifiers.append("⌃") }

            let isSpecial = specialKeys.contains(keyCode)

            if !modifiers.isEmpty || isSpecial {
                var step = MacroStep(kind: .keyShortcut)
                step.value = (modifiers + [keyString]).joined(separator: "+")
                recordedSteps.append(step)
            } else {
                let chars = characterForKeyCode(keyCode)
                if !chars.isEmpty {
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

        case .scrollWheel:
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

            guard amount > 0 else { break }

            if let lastIndex = recordedSteps.indices.last,
               recordedSteps[lastIndex].kind == .scroll,
               recordedSteps[lastIndex].scrollDirection == direction {
                recordedSteps[lastIndex].scrollAmount = min(recordedSteps[lastIndex].scrollAmount + amount, 50)
                recordedSteps[lastIndex].value = "\(direction.title) ×\(Int(recordedSteps[lastIndex].scrollAmount))"
            } else {
                var step = MacroStep(kind: .scroll)
                step.scrollDirection = direction
                step.scrollAmount = min(amount, 50)
                step.scrollMovesMouse = true
                step.scrollX = event.location.x
                step.scrollY = event.location.y
                step.value = "\(direction.title) ×\(Int(step.scrollAmount))"
                recordedSteps.append(step)
            }

        default:
            break
        }
    }

    private func keyNameForCode(_ keyCode: CGKeyCode) -> String {
        let map: [CGKeyCode: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space",
            50: "`", 51: "Delete", 53: "Escape", 76: "Enter",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
            115: "Home", 116: "PageUp", 117: "ForwardDelete", 119: "End",
            121: "PageDown",
            123: "Left", 124: "Right", 125: "Down", 126: "Up",
        ]
        return map[keyCode] ?? "Key\(keyCode)"
    }

    private func characterForKeyCode(_ keyCode: CGKeyCode) -> String {
        let map: [CGKeyCode: String] = [
            0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x",
            8: "c", 9: "v", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r",
            16: "y", 17: "t", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "o", 32: "u", 33: "[", 34: "i", 35: "p",
            37: "l", 38: "j", 39: "'", 40: "k", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "n", 46: "m", 47: ".", 49: " ", 50: "`",
        ]
        return map[keyCode] ?? ""
    }
}

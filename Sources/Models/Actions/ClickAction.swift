import AppKit
import Foundation

struct ClickAction: MacroAction {
    func execute(step: MacroStep) async -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        let target = CGPoint(x: step.clickX, y: step.clickY)

        let currentPos = CGEvent(source: nil)?.location ?? target
        let dx = target.x - currentPos.x
        let dy = target.y - currentPos.y
        let distance = sqrt(dx * dx + dy * dy)

        if distance > 2 {
            let moveSteps = max(20, min(60, Int(distance / 8)))
            for i in 1...moveSteps {
                let t = Double(i) / Double(moveSteps)
                let eased = t * t * (3.0 - 2.0 * t)
                let x = currentPos.x + dx * eased
                let y = currentPos.y + dy * eased
                let point = CGPoint(x: x, y: y)

                guard let moveEvent = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) else { return false }
                moveEvent.post(tap: .cghidEventTap)
                try? await Task.sleep(for: .milliseconds(8))
            }
        }

        try? await Task.sleep(for: .milliseconds(30))

        guard let downEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: target, mouseButton: .left),
              let upEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: target, mouseButton: .left)
        else { return false }

        downEvent.setIntegerValueField(.mouseEventClickState, value: 1)
        upEvent.setIntegerValueField(.mouseEventClickState, value: 1)

        downEvent.post(tap: .cghidEventTap)
        try? await Task.sleep(for: .milliseconds(100))
        upEvent.post(tap: .cghidEventTap)
        try? await Task.sleep(for: .milliseconds(80))
        return true
    }
}

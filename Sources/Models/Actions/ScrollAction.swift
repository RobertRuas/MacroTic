import AppKit
import Foundation

struct ScrollAction: MacroAction {
    private static let pixelsPerEvent = 10
    private static let pixelFrameMs = 8
    private static let lineDelayMs = 25

    func execute(step: MacroStep) async -> Bool {
        let total = Int(step.scrollAmount)
        guard total > 0 else { return false }

        let source = CGEventSource(stateID: .combinedSessionState)
        source?.localEventsSuppressionInterval = 0

        if step.scrollMovesMouse && step.hasScrollPosition {
            let point = CGPoint(x: step.scrollX, y: step.scrollY)
            CGAssociateMouseAndMouseCursorPosition(0)
            CGWarpMouseCursorPosition(point)
            CGAssociateMouseAndMouseCursorPosition(1)
            if let move = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) {
                move.post(tap: .cghidEventTap)
            }
            try? await Task.sleep(for: .milliseconds(300))
        }

        let sign = (step.scrollDirection == .up || step.scrollDirection == .left) ? 1 : -1
        let vertical = step.scrollDirection == .up || step.scrollDirection == .down

        switch step.scrollUnit {
        case .lines:
            return await scroll(total, unit: .line, perEvent: 1, delayMs: Self.lineDelayMs, sign: sign, vertical: vertical, source: source)
        case .pixels:
            return await scroll(total, unit: .pixel, perEvent: Self.pixelsPerEvent, delayMs: Self.pixelFrameMs, sign: sign, vertical: vertical, source: source)
        }
    }

    private func scroll(_ total: Int, unit: CGScrollEventUnit, perEvent: Int, delayMs: Int, sign: Int, vertical: Bool, source: CGEventSource?) async -> Bool {
        var remaining = total
        while remaining > 0 {
            let amount = min(perEvent, remaining)
            remaining -= amount
            let value = Int32(amount * sign)
            guard let event = CGEvent(
                scrollWheelEvent2Source: source,
                units: unit,
                wheelCount: 2,
                wheel1: vertical ? value : 0,
                wheel2: vertical ? 0 : value,
                wheel3: 0
            ) else { return false }
            if unit == .pixel {
                event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
            }
            event.post(tap: .cghidEventTap)
            try? await Task.sleep(for: .milliseconds(delayMs))
        }
        return true
    }
}

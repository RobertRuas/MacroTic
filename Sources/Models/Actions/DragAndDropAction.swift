import AppKit
import Foundation

struct DragAndDropAction: MacroAction {
    // Tunable timings (ms) for picking up and dropping the dragged item.
    private static let grabHoldMs = 450      // button held perfectly still before ANY movement (the "grab")
    private static let pickupStepMs = 45     // delay between each tiny pick-up move
    private static let pickupSettleMs = 120  // after the item has lifted, before travelling to the target
    private static let dropDwellMs = 160     // held at the destination before releasing
    private static let afterReleaseMs = 120  // after release, before the next step runs
    private static let pickupSteps = 6       // number of tiny moves used to arm/lift the drag
    private static let pickupDistanceMax = 14.0 // how far (px) the slow pick-up travels

    func execute(step: MacroStep) async -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        let startPoint = CGPoint(x: step.dragStartX, y: step.dragStartY)
        let endPoint = CGPoint(x: step.dragEndX, y: step.dragEndY)

        let currentPos = CGEvent(source: nil)?.location ?? startPoint
        let dx = startPoint.x - currentPos.x
        let dy = startPoint.y - currentPos.y
        let distance = sqrt(dx * dx + dy * dy)

        if distance > 2 {
            let approachSteps = max(20, min(60, Int(distance / 8)))
            for i in 1...approachSteps {
                if Task.isCancelled { return false }
                let t = Double(i) / Double(approachSteps)
                let eased = t * t * (3.0 - 2.0 * t)
                let x = currentPos.x + dx * eased
                let y = currentPos.y + dy * eased
                let point = CGPoint(x: x, y: y)

                guard let moveEvent = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) else { return false }
                moveEvent.post(tap: .cghidEventTap)
                try? await Task.sleep(for: .milliseconds(8))
            }
        }

        try? await Task.sleep(for: .milliseconds(80))

        guard let mouseDown = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: startPoint, mouseButton: .left) else { return false }
        mouseDown.post(tap: .cghidEventTap)

        // From here on the button is DOWN: any early exit must still post mouseUp, so track a flag
        // and fall through to the single release path below instead of returning.
        var cancelled = false

        // Long "grab" hold: keep the button pressed, perfectly still, long enough for the app to
        // treat it as picking up the item (image) under the cursor before any movement happens.
        try? await Task.sleep(for: .milliseconds(Self.grabHoldMs))

        // Slow, deliberate pick-up: cross the drag threshold with several tiny moves so the app
        // arms the drag and the item actually lifts off, instead of reading it as a plain click.
        let totalDX = endPoint.x - startPoint.x
        let totalDY = endPoint.y - startPoint.y
        let totalLen = max(1, sqrt(totalDX * totalDX + totalDY * totalDY))
        let pickupDistance = min(Self.pickupDistanceMax, totalLen)
        let ux = totalDX / totalLen
        let uy = totalDY / totalLen
        var liftPoint = startPoint
        for i in 1...Self.pickupSteps {
            if Task.isCancelled { cancelled = true; break }
            let d = pickupDistance * Double(i) / Double(Self.pickupSteps)
            liftPoint = CGPoint(x: startPoint.x + ux * d, y: startPoint.y + uy * d)
            if let lift = CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged, mouseCursorPosition: liftPoint, mouseButton: .left) {
                lift.post(tap: .cghidEventTap)
            }
            try? await Task.sleep(for: .milliseconds(Self.pickupStepMs))
        }

        // Let the lifted item settle onto the cursor before travelling to the destination.
        if !cancelled { try? await Task.sleep(for: .milliseconds(Self.pickupSettleMs)) }

        let dragSteps = 30
        if !cancelled {
            for i in 1...dragSteps {
                if Task.isCancelled { cancelled = true; break }
                let progress = Double(i) / Double(dragSteps)
                let eased = progress * progress * (3.0 - 2.0 * progress)
                let currentX = liftPoint.x + (endPoint.x - liftPoint.x) * eased
                let currentY = liftPoint.y + (endPoint.y - liftPoint.y) * eased
                let currentPoint = CGPoint(x: currentX, y: currentY)

                guard let dragEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged, mouseCursorPosition: currentPoint, mouseButton: .left) else { break }
                dragEvent.post(tap: .cghidEventTap)
                try? await Task.sleep(for: .milliseconds(12))
            }
        }

        // Settle exactly on the destination and dwell there before releasing — dropping the
        // instant the cursor arrives can land before the target accepts the drag.
        if !cancelled {
            if let settle = CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged, mouseCursorPosition: endPoint, mouseButton: .left) {
                settle.post(tap: .cghidEventTap)
            }
        }
        // Always release the button pressed above, even if cancelled, to avoid a stuck drag.
        try? await Task.sleep(for: .milliseconds(Self.dropDwellMs))
        if let mouseUp = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: endPoint, mouseButton: .left) {
            mouseUp.post(tap: .cghidEventTap)
        }
        // Don't exit immediately after releasing: let the drop fully commit before the next step.
        try? await Task.sleep(for: .milliseconds(Self.afterReleaseMs))
        return !cancelled
    }
}

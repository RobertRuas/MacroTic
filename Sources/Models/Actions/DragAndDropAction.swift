import AppKit
import Foundation

struct DragAndDropAction: MacroAction {
    func execute(step: MacroStep) async -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        source?.localEventsSuppressionInterval = 0
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

        // Warp exactly to the start, re-associate and settle, then post an explicit move AT the
        // start point so the window/item under the cursor registers hover and focus BEFORE the
        // press. Without this, a mouseDown on a not-yet-focused window (e.g. the first grab after
        // a scroll or a big cursor jump) is swallowed as a mere window-raise and the item is never
        // picked up — exactly what ClickAction already does for clicks.
        CGWarpMouseCursorPosition(startPoint)
        CGAssociateMouseAndMouseCursorPosition(1)
        try? await Task.sleep(for: .milliseconds(60))
        if Task.isCancelled { return false }
        if let settleMove = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: startPoint, mouseButton: .left) {
            settleMove.post(tap: .cghidEventTap)
        }
        try? await Task.sleep(for: .milliseconds(40))
        if Task.isCancelled { return false }

        guard let mouseDown = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: startPoint, mouseButton: .left) else { return false }
        mouseDown.setIntegerValueField(.mouseEventClickState, value: 1)
        mouseDown.post(tap: .cghidEventTap)
        // Hold the press in place so the target under the cursor registers the grab
        // before any movement — releasing/moving too soon makes the drag silently fail.
        try? await Task.sleep(for: .milliseconds(220))

        // A tiny initial drag nudge "wakes up" apps that only begin a drag once the
        // pointer actually moves while the button is down.
        if !Task.isCancelled {
            let nudge = CGPoint(x: startPoint.x + 1, y: startPoint.y + 1)
            if let wake = CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged, mouseCursorPosition: nudge, mouseButton: .left) {
                wake.post(tap: .cghidEventTap)
            }
            try? await Task.sleep(for: .milliseconds(90))
        }

        let dragSteps = 30
        var cancelled = false
        for i in 1...dragSteps {
            if Task.isCancelled { cancelled = true; break }
            let progress = Double(i) / Double(dragSteps)
            let eased = progress * progress * (3.0 - 2.0 * progress)
            let currentX = step.dragStartX + (step.dragEndX - step.dragStartX) * eased
            let currentY = step.dragStartY + (step.dragEndY - step.dragStartY) * eased
            let currentPoint = CGPoint(x: currentX, y: currentY)

            guard let dragEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged, mouseCursorPosition: currentPoint, mouseButton: .left) else { break }
            dragEvent.post(tap: .cghidEventTap)
            try? await Task.sleep(for: .milliseconds(12))
        }

        // Settle exactly on the destination and dwell there before releasing — dropping the
        // instant the cursor arrives can land before the target accepts the drag.
        if !cancelled {
            if let settle = CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged, mouseCursorPosition: endPoint, mouseButton: .left) {
                settle.post(tap: .cghidEventTap)
            }
        }
        // Always release the button pressed above, even if cancelled, to avoid a stuck drag.
        try? await Task.sleep(for: .milliseconds(160))
        if let mouseUp = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: endPoint, mouseButton: .left) {
            mouseUp.setIntegerValueField(.mouseEventClickState, value: 1)
            mouseUp.post(tap: .cghidEventTap)
        }
        // Don't exit immediately after releasing: let the drop fully commit before the next step.
        try? await Task.sleep(for: .milliseconds(120))
        return !cancelled
    }
}

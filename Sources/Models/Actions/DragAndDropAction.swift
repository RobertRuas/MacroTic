import AppKit
import Foundation

struct DragAndDropAction: MacroAction {
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
        try? await Task.sleep(for: .milliseconds(120))

        let dragSteps = 30
        for i in 1...dragSteps {
            let progress = Double(i) / Double(dragSteps)
            let eased = progress * progress * (3.0 - 2.0 * progress)
            let currentX = step.dragStartX + (step.dragEndX - step.dragStartX) * eased
            let currentY = step.dragStartY + (step.dragEndY - step.dragStartY) * eased
            let currentPoint = CGPoint(x: currentX, y: currentY)

            guard let dragEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged, mouseCursorPosition: currentPoint, mouseButton: .left) else { return false }
            dragEvent.post(tap: .cghidEventTap)
            try? await Task.sleep(for: .milliseconds(12))
        }

        try? await Task.sleep(for: .milliseconds(50))
        guard let mouseUp = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: endPoint, mouseButton: .left) else { return false }
        mouseUp.post(tap: .cghidEventTap)
        try? await Task.sleep(for: .milliseconds(50))
        return true
    }
}

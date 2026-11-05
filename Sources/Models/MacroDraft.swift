import AppKit

@Observable
final class MacroDraft {
    var name: String = ""
    var details: String = ""
    var iconName: String = "command.circle.fill"
    var steps: [MacroStep] = []
    var intervalBetweenSteps: Double = 0.5
    var repeatCount: Int = 1
    var dropTargetID: UUID? = nil

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isValid: Bool {
        !trimmedName.isEmpty && !steps.isEmpty
    }

    func add(_ kind: MacroStepKind) {
        var step = MacroStep(kind: kind)
        if kind == .delay { step.delay = 0.5 }
        steps.append(step)
        if kind == .typeText {
            StepFocusRequest.pendingStepID = step.id
        }
        if kind == .keyShortcut {
            ShortcutCapturePicker.pickShortcut { [weak self] shortcut in
                DispatchQueue.main.async {
                    guard let self, let i = self.steps.firstIndex(where: { $0.id == step.id }) else { return }
                    self.steps[i].value = shortcut
                }
            }
        }
        if kind == .click {
            ScreenCoordinatePicker.pickPoint { [weak self] point in
                DispatchQueue.main.async {
                    guard let self, let i = self.steps.firstIndex(where: { $0.id == step.id }) else { return }
                    self.steps[i].setClickPoint(point)
                }
            }
        }
        if kind == .dragAndDrop {
            ScreenCoordinatePicker.pickDrag { [weak self] start, end in
                DispatchQueue.main.async {
                    guard let self, let i = self.steps.firstIndex(where: { $0.id == step.id }) else { return }
                    var s = self.steps[i]
                    s.dragStartX = start.x
                    s.dragStartY = start.y
                    s.dragEndX = end.x
                    s.dragEndY = end.y
                    s.value = "(\(Int(start.x)),\(Int(start.y))) → (\(Int(end.x)),\(Int(end.y)))"
                    self.steps[i] = s
                }
            }
        }
    }

    func remove(_ id: UUID) {
        steps.removeAll { $0.id == id }
    }

    func moveUp(_ id: UUID) {
        guard let index = steps.firstIndex(where: { $0.id == id }), index > 0 else { return }
        steps.swapAt(index, index - 1)
    }

    func moveDown(_ id: UUID) {
        guard let index = steps.firstIndex(where: { $0.id == id }), index < steps.count - 1 else { return }
        steps.swapAt(index, index + 1)
    }

    func move(_ id: UUID, before targetID: UUID) {
        guard id != targetID,
              let from = steps.firstIndex(where: { $0.id == id }),
              let to = steps.firstIndex(where: { $0.id == targetID }) else { return }
        let step = steps.remove(at: from)
        steps.insert(step, at: to)
    }

    func duplicate(_ id: UUID) {
        guard let index = steps.firstIndex(where: { $0.id == id }) else { return }
        steps.insert(steps[index].copyWithNewID(), at: index + 1)
    }

    func loadFrom(_ macro: Macro) {
        name = macro.name
        details = macro.details
        iconName = macro.iconName
        steps = macro.steps
        intervalBetweenSteps = macro.intervalBetweenSteps
        repeatCount = macro.repeatCount
    }

    func makeMacro() -> Macro {
        Macro(
            name: trimmedName,
            details: details.trimmingCharacters(in: .whitespacesAndNewlines),
            iconName: iconName,
            steps: steps,
            intervalBetweenSteps: intervalBetweenSteps,
            repeatCount: repeatCount
        )
    }

    func makeMacro(preservingID id: UUID, createdAt: Date, lastUsedAt: Date?, executionCount: Int) -> Macro {
        var macro = Macro(
            id: id,
            name: trimmedName,
            details: details.trimmingCharacters(in: .whitespacesAndNewlines),
            iconName: iconName,
            steps: steps,
            intervalBetweenSteps: intervalBetweenSteps,
            repeatCount: repeatCount
        )
        macro.createdAt = createdAt
        macro.lastUsedAt = lastUsedAt
        macro.executionCount = executionCount
        return macro
    }
}

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
        let step = MacroStep(kind: kind)
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
        var copy = steps[index]
        copy = MacroStep(kind: copy.kind)
        copy.value = steps[index].value
        copy.delay = steps[index].delay
        copy.clickX = steps[index].clickX
        copy.clickY = steps[index].clickY
        copy.dragStartX = steps[index].dragStartX
        copy.dragStartY = steps[index].dragStartY
        copy.dragEndX = steps[index].dragEndX
        copy.dragEndY = steps[index].dragEndY
        copy.scrollDirection = steps[index].scrollDirection
        copy.scrollAmount = steps[index].scrollAmount
        steps.insert(copy, at: index + 1)
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

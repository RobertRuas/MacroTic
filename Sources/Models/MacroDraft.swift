import Foundation

@Observable
final class MacroDraft {
    var name: String = ""
    var details: String = ""
    var iconName: String = "command.circle.fill"
    var steps: [MacroStep] = []
    var selectedStepID: UUID? = nil

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isValid: Bool {
        !trimmedName.isEmpty && !steps.isEmpty
    }

    func add(_ kind: MacroStepKind) {
        let step = MacroStep(kind: kind)
        steps.append(step)
        selectedStepID = step.id
    }

    func remove(_ id: UUID) {
        let wasSelected = selectedStepID == id
        steps.removeAll { $0.id == id }
        if wasSelected {
            selectedStepID = steps.last?.id
        }
    }

    func moveUp(_ id: UUID) {
        guard let index = steps.firstIndex(where: { $0.id == id }), index > 0 else { return }
        steps.swapAt(index, index - 1)
    }

    func moveDown(_ id: UUID) {
        guard let index = steps.firstIndex(where: { $0.id == id }), index < steps.count - 1 else { return }
        steps.swapAt(index, index + 1)
    }

    func moveSelectedUp() {
        guard let id = selectedStepID else { return }
        moveUp(id)
    }

    func moveSelectedDown() {
        guard let id = selectedStepID else { return }
        moveDown(id)
    }

    func loadFrom(_ macro: Macro) {
        name = macro.name
        details = macro.details
        iconName = macro.iconName
        steps = macro.steps
        selectedStepID = nil
    }

    func makeMacro() -> Macro {
        Macro(
            name: trimmedName,
            details: details.trimmingCharacters(in: .whitespacesAndNewlines),
            iconName: iconName,
            steps: steps
        )
    }

    func makeMacro(preservingID id: UUID, createdAt: Date, lastUsedAt: Date?, executionCount: Int) -> Macro {
        var macro = Macro(
            id: id,
            name: trimmedName,
            details: details.trimmingCharacters(in: .whitespacesAndNewlines),
            iconName: iconName,
            steps: steps
        )
        macro.createdAt = createdAt
        macro.lastUsedAt = lastUsedAt
        macro.executionCount = executionCount
        return macro
    }
}

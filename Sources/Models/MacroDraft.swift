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
    var selectedStepIDs: Set<UUID> = []
    var debugMode: Bool = false
    var showQuickBar: Bool = true
    var isLocked: Bool = false

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
        selectedStepIDs.remove(id)
    }

    // MARK: - Selection

    func toggleSelection(_ id: UUID) {
        if selectedStepIDs.contains(id) {
            selectedStepIDs.remove(id)
        } else {
            selectedStepIDs.insert(id)
        }
    }

    var allSelected: Bool {
        !steps.isEmpty && selectedStepIDs.count == steps.count
    }

    func selectAll() {
        selectedStepIDs = Set(steps.map(\.id))
    }

    func clearSelection() {
        selectedStepIDs.removeAll()
    }

    func removeSelected() {
        guard !selectedStepIDs.isEmpty else { return }
        steps.removeAll { selectedStepIDs.contains($0.id) }
        selectedStepIDs.removeAll()
    }

    /// Selected steps in their current list order.
    func selectedStepsInOrder() -> [MacroStep] {
        steps.filter { selectedStepIDs.contains($0.id) }
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
        guard !selectedStepIDs.isEmpty else { return }
        var result = steps
        let n = result.count
        var i = 0
        while i < n {
            if selectedStepIDs.contains(result[i].id) {
                var j = i
                while j < n && selectedStepIDs.contains(result[j].id) { j += 1 }
                if i > 0 {
                    let above = result.remove(at: i - 1)
                    result.insert(above, at: j - 1)
                }
                i = j
            } else {
                i += 1
            }
        }
        steps = result
    }

    func moveSelectedDown() {
        guard !selectedStepIDs.isEmpty else { return }
        var result = steps
        let n = result.count
        var i = n - 1
        while i >= 0 {
            if selectedStepIDs.contains(result[i].id) {
                var j = i
                while j >= 0 && selectedStepIDs.contains(result[j].id) { j -= 1 }
                if i < n - 1 {
                    let below = result.remove(at: i + 1)
                    result.insert(below, at: j + 1)
                }
                i = j
            } else {
                i -= 1
            }
        }
        steps = result
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
        isLocked = macro.isLocked
    }

    func makeMacro() -> Macro {
        var macro = Macro(
            name: trimmedName,
            details: details.trimmingCharacters(in: .whitespacesAndNewlines),
            iconName: iconName,
            steps: steps,
            intervalBetweenSteps: intervalBetweenSteps,
            repeatCount: repeatCount
        )
        macro.isLocked = isLocked
        return macro
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
        macro.isLocked = isLocked
        return macro
    }
}

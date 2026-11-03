import AppKit

@Observable
final class ActionTester {
    var steps: [MacroStep] = []
    var countdownSeconds: Int = 3
    var hidesApp: Bool = false
    var intervalBetweenSteps: Double = 0.5
    var log: [TestLogEntry] = []
    var runningStepID: UUID? = nil
    var remainingCountdown: Int = 0
    var isBusy: Bool = false

    private let executor: MacroExecutor
    private var task: Task<Void, Never>?

    init(executor: MacroExecutor) {
        self.executor = executor
    }

    func addStep(_ kind: MacroStepKind) {
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

    func removeStep(_ id: UUID) {
        steps.removeAll { $0.id == id }
    }

    func duplicateStep(_ id: UUID) {
        guard let index = steps.firstIndex(where: { $0.id == id }) else { return }
        let source = steps[index]
        var copy = MacroStep(kind: source.kind)
        copy.value = source.value
        copy.delay = source.delay
        copy.clickX = source.clickX
        copy.clickY = source.clickY
        copy.dragStartX = source.dragStartX
        copy.dragStartY = source.dragStartY
        copy.dragEndX = source.dragEndX
        copy.dragEndY = source.dragEndY
        copy.scrollDirection = source.scrollDirection
        copy.scrollAmount = source.scrollAmount
        steps.insert(copy, at: index + 1)
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

    func clearLog() {
        log.removeAll()
    }

    func test(_ step: MacroStep) {
        run([step])
    }

    func testAll() {
        run(steps)
    }

    func cancel() {
        task?.cancel()
        task = nil
        finish()
    }

    private func run(_ queue: [MacroStep]) {
        guard !isBusy, !queue.isEmpty else { return }
        isBusy = true
        let seconds = countdownSeconds
        let hide = hidesApp
        let interval = intervalBetweenSteps
        let actions = executor.actions

        task = Task { @MainActor [weak self] in
            guard let self else { return }

            var remaining = seconds
            while remaining > 0 {
                self.remainingCountdown = remaining
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                remaining -= 1
            }
            self.remainingCountdown = 0

            if hide { NSApp.hide(nil) }

            for (index, step) in queue.enumerated() {
                if Task.isCancelled { break }
                self.runningStepID = step.id

                let started = Date()
                var success = false
                if let action = actions[step.kind] {
                    success = await Task.detached(priority: .userInitiated) {
                        await action.execute(step: step)
                    }.value
                }

                self.log.insert(
                    TestLogEntry(
                        date: started,
                        kind: step.kind,
                        detail: Self.describe(step),
                        success: success,
                        duration: Date().timeIntervalSince(started)
                    ),
                    at: 0
                )

                if !success { break }
                if index < queue.count - 1 {
                    try? await Task.sleep(for: .milliseconds(Int(interval * 1000)))
                }
            }

            if hide { NSApp.unhide(nil) }
            self.finish()
        }
    }

    private func finish() {
        runningStepID = nil
        remainingCountdown = 0
        isBusy = false
    }

    static func describe(_ step: MacroStep) -> String {
        switch step.kind {
        case .click:
            return "(\(Int(step.clickX)), \(Int(step.clickY)))"
        case .dragAndDrop:
            return "(\(Int(step.dragStartX)), \(Int(step.dragStartY))) → (\(Int(step.dragEndX)), \(Int(step.dragEndY)))"
        case .scroll:
            return step.scrollSummary
        case .delay:
            return "\(Int((step.delay * 1000).rounded())) ms"
        default:
            if step.kind == .typeText { return "\(step.textMode.title): \(step.value)" }
            return step.value.isEmpty ? "—" : step.value
        }
    }
}

import AppKit
import Foundation

enum MacroExecutionState: Equatable {
    case idle
    case running(stepIndex: Int, totalSteps: Int)
    case paused(stepIndex: Int, totalSteps: Int)
    case finished
    case error(String)
}

@Observable
final class MacroExecutor {
    var state: MacroExecutionState = .idle
    var currentRepetition: Int = 1
    var totalRepetitions: Int = 1
    private var shouldStop = false
    private var isPaused = false
    private var currentTask: Task<Void, Never>?
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?

    private func installStopShortcut() {
        removeStopShortcut()
        let handler: (NSEvent) -> Bool = { event in
            event.keyCode == 53 && event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command)
        }
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if handler(event) { DispatchQueue.main.async { self?.stop() } }
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if handler(event) {
                self?.stop()
                return nil
            }
            return event
        }
    }

    private func removeStopShortcut() {
        if let m = globalKeyMonitor { NSEvent.removeMonitor(m) }
        if let m = localKeyMonitor { NSEvent.removeMonitor(m) }
        globalKeyMonitor = nil
        localKeyMonitor = nil
    }

    let actions: [MacroStepKind: MacroAction] = [
        .keyShortcut: KeyShortcutAction(),
        .typeText: TypeTextAction(),
        .click: ClickAction(),
        .delay: DelayAction(),
        .launchApp: FocusWindowAction(),
        .dragAndDrop: DragAndDropAction(),
        .scroll: ScrollAction(),
    ]

    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    var isPausedState: Bool {
        if case .paused = state { return true }
        return false
    }

    func execute(_ macro: Macro) {
        guard !isRunning else { return }
        shouldStop = false
        isPaused = false

        let originalCursor = CGEvent(source: nil)?.location
        installStopShortcut()

        let steps = macro.steps
        let repetitions = max(1, macro.repeatCount)
        currentRepetition = 1
        totalRepetitions = repetitions
        let interval = macro.intervalBetweenSteps

        currentTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }

            defer {
                if let p = originalCursor {
                    CGWarpMouseCursorPosition(p)
                    CGAssociateMouseAndMouseCursorPosition(1)
                }
            }

            for repetition in 1...repetitions {
                if self.shouldStop { break }
                await MainActor.run { self.currentRepetition = repetition }
                for (index, step) in steps.enumerated() {
                    if self.shouldStop { break }

                    while self.isPaused {
                        if self.shouldStop { break }
                        try? await Task.sleep(for: .milliseconds(100))
                    }
                    if self.shouldStop { break }

                    await MainActor.run {
                        self.state = .running(stepIndex: index, totalSteps: steps.count)
                    }

                    guard let action = self.actions[step.kind] else {
                        await MainActor.run {
                            self.removeStopShortcut()
                            self.state = .error("Ação desconhecida: \(step.kind.title)")
                            self.activateApp()
                        }
                        return
                    }

                    let success = await action.execute(step: step)
                    if !success {
                        await MainActor.run {
                            self.removeStopShortcut()
                            self.state = .error("Falha ao executar passo \(index + 1): \(step.kind.title)")
                            self.activateApp()
                        }
                        return
                    }

                    if index < steps.count - 1 || repetition < repetitions {
                        try? await Task.sleep(for: .milliseconds(Int(interval * 1000)))
                    }
                }
            }

            await MainActor.run {
                self.removeStopShortcut()
                if !self.shouldStop {
                    self.state = .finished
                } else {
                    self.state = .idle
                }
                self.activateApp()
            }
        }
    }

    private func activateApp() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.isVisible && !$0.isKind(of: NSPanel.self) }?.makeKeyAndOrderFront(nil)
    }

    func pause() {
        guard isRunning else { return }
        isPaused = true
        if case .running(let idx, let total) = state {
            state = .paused(stepIndex: idx, totalSteps: total)
        }
    }

    func resume() {
        guard isPausedState else { return }
        isPaused = false
    }

    func stop() {
        removeStopShortcut()
        shouldStop = true
        isPaused = false
        currentTask?.cancel()
        currentTask = nil
        state = .idle
        activateApp()
    }
}

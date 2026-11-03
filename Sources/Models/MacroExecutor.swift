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
    private var shouldStop = false
    private var isPaused = false
    private var currentTask: Task<Void, Never>?

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

        currentTask = Task { @MainActor in
            let steps = macro.steps
            for (index, step) in steps.enumerated() {
                if shouldStop { break }

                while isPaused {
                    if shouldStop { break }
                    try? await Task.sleep(for: .milliseconds(100))
                }
                if shouldStop { break }

                state = .running(stepIndex: index, totalSteps: steps.count)

                let success = await executeStep(step)
                if !success {
                    state = .error("Falha ao executar passo \(index + 1): \(step.kind.title)")
                    return
                }
            }

            if !shouldStop {
                state = .finished
            } else {
                state = .idle
            }
        }
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
        shouldStop = true
        isPaused = false
        currentTask?.cancel()
        currentTask = nil
        state = .idle
    }

    private func executeStep(_ step: MacroStep) async -> Bool {
        switch step.kind {
        case .keyShortcut:
            return executeKeyShortcut(step.value)
        case .typeText:
            return executeTypeText(step.value)
        case .click:
            return executeClick(x: step.clickX, y: step.clickY)
        case .delay:
            return await executeDelay(step.delay)
        case .launchApp:
            return executeLaunchApp(step.value)
        case .openURL:
            return executeOpenURL(step.value)
        case .dragAndDrop:
            return executeDragAndDrop(
                startX: step.dragStartX, startY: step.dragStartY,
                endX: step.dragEndX, endY: step.dragEndY
            )
        case .scroll:
            return executeScroll(direction: step.scrollDirection, amount: step.scrollAmount)
        }
    }

    // MARK: - Key Shortcut

    private func executeKeyShortcut(_ value: String) -> Bool {
        let parts = value.split(separator: "+")
        guard let keyPart = parts.last else { return false }

        var flags: CGEventFlags = []
        for modifier in parts.dropLast() {
            switch modifier.trimmingCharacters(in: .whitespaces).lowercased() {
            case "⌘", "cmd", "command": flags.insert(.maskCommand)
            case "⌥", "opt", "option", "alt": flags.insert(.maskAlternate)
            case "⇧", "shift": flags.insert(.maskShift)
            case "⌃", "ctrl", "control": flags.insert(.maskControl)
            default: break
            }
        }

        let keyString = keyPart.trimmingCharacters(in: .whitespaces)
        guard let keyCode = keyCodeForString(keyString) else { return false }

        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return false }

        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    private func keyCodeForString(_ key: String) -> CGKeyCode? {
        let map: [String: CGKeyCode] = [
            "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5,
            "h": 4, "i": 34, "j": 38, "k": 40, "l": 37, "m": 46, "n": 45,
            "o": 31, "p": 35, "q": 12, "r": 15, "s": 1, "t": 17, "u": 32,
            "v": 9, "w": 13, "x": 7, "y": 16, "z": 6,
            "0": 29, "1": 18, "2": 19, "3": 20, "4": 21,
            "5": 23, "6": 22, "7": 26, "8": 28, "9": 25,
            "return": 36, "enter": 36, "tab": 48, "space": 49,
            "delete": 51, "backspace": 51, "escape": 53, "esc": 53,
            "left": 123, "right": 124, "down": 125, "up": 126,
            "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96,
            "f6": 97, "f7": 98, "f8": 100, "f9": 101, "f10": 109,
            "f11": 103, "f12": 111,
            "-": 27, "=": 24, "[": 33, "]": 30, "\\": 42,
            ";": 41, "'": 39, ",": 43, ".": 47, "/": 44, "`": 50,
        ]
        return map[key.lowercased()]
    }

    // MARK: - Type Text

    private func executeTypeText(_ text: String) -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        for char in text {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) else { return false }
            var utf16 = Array(String(char).utf16)
            event.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            event.post(tap: .cghidEventTap)

            guard let upEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return false }
            upEvent.post(tap: .cghidEventTap)
            usleep(20_000)
        }
        return true
    }

    // MARK: - Click

    private func executeClick(x: Double, y: Double) -> Bool {
        let point = CGPoint(x: x, y: y)
        let source = CGEventSource(stateID: .hidSystemState)

        guard let moveEvent = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) else { return false }
        moveEvent.post(tap: .cghidEventTap)

        guard let downEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
              let upEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        else { return false }

        downEvent.post(tap: .cghidEventTap)
        usleep(50_000)
        upEvent.post(tap: .cghidEventTap)
        return true
    }

    // MARK: - Delay

    private func executeDelay(_ seconds: Double) async -> Bool {
        try? await Task.sleep(for: .milliseconds(Int(seconds * 1000)))
        return true
    }

    // MARK: - Launch App

    private func executeLaunchApp(_ appName: String) -> Bool {
        let workspace = NSWorkspace.shared
        if let url = workspace.urlForApplication(withBundleIdentifier: appName) {
            let config = NSWorkspace.OpenConfiguration()
            workspace.openApplication(at: url, configuration: config)
            return true
        }
        let trimmed = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let appURL = URL(fileURLWithPath: "/Applications/\(trimmed).app")
            if FileManager.default.fileExists(atPath: appURL.path) {
                return NSWorkspace.shared.open(appURL)
            }
        }
        return false
    }

    // MARK: - Open URL

    private func executeOpenURL(_ urlString: String) -> Bool {
        var str = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !str.contains("://") { str = "https://\(str)" }
        guard let url = URL(string: str) else { return false }
        return NSWorkspace.shared.open(url)
    }

    // MARK: - Drag and Drop

    private func executeDragAndDrop(startX: Double, startY: Double, endX: Double, endY: Double) -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        let startPoint = CGPoint(x: startX, y: startY)
        let endPoint = CGPoint(x: endX, y: endY)

        guard let moveToStart = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: startPoint, mouseButton: .left) else { return false }
        moveToStart.post(tap: .cghidEventTap)
        usleep(50_000)

        guard let mouseDown = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: startPoint, mouseButton: .left) else { return false }
        mouseDown.post(tap: .cghidEventTap)
        usleep(100_000)

        let dragSteps = 20
        for i in 1...dragSteps {
            let progress = Double(i) / Double(dragSteps)
            let currentX = startX + (endX - startX) * progress
            let currentY = startY + (endY - startY) * progress
            let currentPoint = CGPoint(x: currentX, y: currentY)

            guard let dragEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged, mouseCursorPosition: currentPoint, mouseButton: .left) else { return false }
            dragEvent.post(tap: .cghidEventTap)
            usleep(15_000)
        }

        guard let mouseUp = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: endPoint, mouseButton: .left) else { return false }
        mouseUp.post(tap: .cghidEventTap)
        return true
    }

    // MARK: - Scroll

    private func executeScroll(direction: ScrollDirection, amount: Double) -> Bool {
        let scrollAmount = Int32(amount)
        var deltaY: Int32 = 0
        var deltaX: Int32 = 0

        switch direction {
        case .up: deltaY = scrollAmount
        case .down: deltaY = -scrollAmount
        case .left: deltaX = scrollAmount
        case .right: deltaX = -scrollAmount
        }

        guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: deltaY, wheel2: deltaX, wheel3: 0) else { return false }
        event.post(tap: .cghidEventTap)
        return true
    }
}

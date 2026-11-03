import Foundation

struct DelayAction: MacroAction {
    func execute(step: MacroStep) async -> Bool {
        try? await Task.sleep(for: .milliseconds(Int(step.delay * 1000)))
        return true
    }
}

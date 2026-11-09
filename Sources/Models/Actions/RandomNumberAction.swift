import AppKit
import Foundation

struct RandomNumberAction: MacroAction {
    func execute(step: MacroStep) async -> Bool {
        let lo = min(step.randomMin, step.randomMax)
        let hi = max(step.randomMin, step.randomMax)
        let value = String(Int.random(in: lo...hi))

        var typed = MacroStep(kind: .typeText)
        typed.value = value
        typed.textMode = step.textMode
        return await TypeTextAction().execute(step: typed)
    }
}

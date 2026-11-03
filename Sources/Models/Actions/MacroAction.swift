import Foundation

protocol MacroAction {
    func execute(step: MacroStep) async -> Bool
}

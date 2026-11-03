import Foundation

struct Macro: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var details: String
    var iconName: String
    var steps: [MacroStep]
    var createdAt: Date
    var lastUsedAt: Date?
    var executionCount: Int

    init(id: UUID = UUID(), name: String, details: String, iconName: String, steps: [MacroStep]) {
        self.id = id
        self.name = name
        self.details = details
        self.iconName = iconName
        self.steps = steps
        self.createdAt = Date()
        self.lastUsedAt = nil
        self.executionCount = 0
    }

    var lastUsedLabel: String {
        guard let date = lastUsedAt else { return "Nunca usado" }
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Agora" }
        if interval < 3600 {
            let mins = Int(interval / 60)
            return "Há \(mins) min"
        }
        if interval < 86400 {
            let hours = Int(interval / 3600)
            return hours == 1 ? "Há 1 hora" : "Há \(hours) horas"
        }
        let days = Int(interval / 86400)
        if days == 1 { return "Ontem" }
        return "Há \(days) dias"
    }
}

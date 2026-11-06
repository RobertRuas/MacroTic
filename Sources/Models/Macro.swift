import Foundation

struct Macro: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var details: String
    var iconName: String
    var steps: [MacroStep]
    var intervalBetweenSteps: Double
    var repeatCount: Int
    var createdAt: Date
    var lastUsedAt: Date?
    var executionCount: Int
    var isFavorite: Bool
    var isLocked: Bool

    init(
        id: UUID = UUID(),
        name: String,
        details: String,
        iconName: String,
        steps: [MacroStep],
        intervalBetweenSteps: Double = 0.5,
        repeatCount: Int = 1
    ) {
        self.id = id
        self.name = name
        self.details = details
        self.iconName = iconName
        self.steps = steps
        self.intervalBetweenSteps = intervalBetweenSteps
        self.repeatCount = max(1, repeatCount)
        self.createdAt = Date()
        self.lastUsedAt = nil
        self.executionCount = 0
        self.isFavorite = false
        self.isLocked = false
    }

    var createdAtLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: createdAt)
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

    enum CodingKeys: String, CodingKey {
        case id, name, details, iconName, steps, intervalBetweenSteps, repeatCount, createdAt, lastUsedAt, executionCount, isFavorite, isLocked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        details = try container.decode(String.self, forKey: .details)
        iconName = try container.decode(String.self, forKey: .iconName)
        steps = try container.decode([LossyStep].self, forKey: .steps).compactMap(\.step)
        intervalBetweenSteps = try container.decodeIfPresent(Double.self, forKey: .intervalBetweenSteps) ?? 0.5
        repeatCount = max(1, try container.decodeIfPresent(Int.self, forKey: .repeatCount) ?? 1)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt)
        executionCount = try container.decode(Int.self, forKey: .executionCount)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
    }
}

private struct LossyStep: Decodable {
    let step: MacroStep?

    init(from decoder: Decoder) throws {
        step = try? MacroStep(from: decoder)
    }
}

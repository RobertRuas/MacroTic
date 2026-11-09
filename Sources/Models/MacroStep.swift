import Foundation

enum ScrollDirection: String, CaseIterable, Identifiable, Codable {
    case up
    case down
    case left
    case right

    var id: String { rawValue }

    var title: String {
        switch self {
        case .up: "Cima"
        case .down: "Baixo"
        case .left: "Esquerda"
        case .right: "Direita"
        }
    }

    var icon: String {
        switch self {
        case .up: "arrow.up"
        case .down: "arrow.down"
        case .left: "arrow.left"
        case .right: "arrow.right"
        }
    }
}

enum ScrollUnit: String, CaseIterable, Identifiable, Codable {
    case lines
    case pixels

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lines: "Linhas"
        case .pixels: "Pixels"
        }
    }
}

enum TextInputMode: String, CaseIterable, Identifiable, Codable {
    case typing
    case paste

    var id: String { rawValue }

    var title: String {
        switch self {
        case .typing: "Tecla por tecla"
        case .paste: "Copiar e colar"
        }
    }
}

struct MacroStep: Identifiable, Hashable, Codable {
    let id: UUID
    var kind: MacroStepKind
    var value: String
    var delay: Double

    var clickX: Double
    var clickY: Double

    var dragStartX: Double
    var dragStartY: Double
    var dragEndX: Double
    var dragEndY: Double

    var scrollDirection: ScrollDirection
    var scrollAmount: Double
    var scrollMovesMouse: Bool
    var scrollX: Double
    var scrollY: Double
    var scrollUnit: ScrollUnit
    var scrollStepDelayMs: Int

    var textMode: TextInputMode

    var randomMin: Int
    var randomMax: Int

    enum CodingKeys: String, CodingKey {
        case id, kind, value, delay, clickX, clickY
        case dragStartX, dragStartY, dragEndX, dragEndY
        case scrollDirection, scrollAmount, scrollMovesMouse, scrollX, scrollY, scrollUnit, scrollStepDelayMs
        case textMode
        case randomMin, randomMax
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        kind = try c.decode(MacroStepKind.self, forKey: .kind)
        value = try c.decodeIfPresent(String.self, forKey: .value) ?? ""
        delay = try c.decodeIfPresent(Double.self, forKey: .delay) ?? 1.0
        clickX = try c.decodeIfPresent(Double.self, forKey: .clickX) ?? 0
        clickY = try c.decodeIfPresent(Double.self, forKey: .clickY) ?? 0
        dragStartX = try c.decodeIfPresent(Double.self, forKey: .dragStartX) ?? 0
        dragStartY = try c.decodeIfPresent(Double.self, forKey: .dragStartY) ?? 0
        dragEndX = try c.decodeIfPresent(Double.self, forKey: .dragEndX) ?? 0
        dragEndY = try c.decodeIfPresent(Double.self, forKey: .dragEndY) ?? 0
        scrollDirection = try c.decodeIfPresent(ScrollDirection.self, forKey: .scrollDirection) ?? .down
        scrollAmount = try c.decodeIfPresent(Double.self, forKey: .scrollAmount) ?? 3.0
        scrollMovesMouse = try c.decodeIfPresent(Bool.self, forKey: .scrollMovesMouse) ?? false
        scrollX = try c.decodeIfPresent(Double.self, forKey: .scrollX) ?? 0
        scrollY = try c.decodeIfPresent(Double.self, forKey: .scrollY) ?? 0
        scrollUnit = try c.decodeIfPresent(ScrollUnit.self, forKey: .scrollUnit) ?? .lines
        scrollStepDelayMs = try c.decodeIfPresent(Int.self, forKey: .scrollStepDelayMs) ?? 25
        textMode = try c.decodeIfPresent(TextInputMode.self, forKey: .textMode) ?? .typing
        randomMin = try c.decodeIfPresent(Int.self, forKey: .randomMin) ?? 1
        randomMax = try c.decodeIfPresent(Int.self, forKey: .randomMax) ?? 100
    }

    init(kind: MacroStepKind) {
        self.id = UUID()
        self.kind = kind
        self.value = ""
        self.delay = 1.0
        self.clickX = 0
        self.clickY = 0
        self.dragStartX = 0
        self.dragStartY = 0
        self.dragEndX = 0
        self.dragEndY = 0
        self.scrollDirection = .down
        self.scrollAmount = 3.0
        self.scrollMovesMouse = false
        self.scrollX = 0
        self.scrollY = 0
        self.scrollUnit = .lines
        self.scrollStepDelayMs = 25
        self.textMode = .typing
        self.randomMin = 1
        self.randomMax = 100
    }

    var scrollSummary: String {
        let unit = scrollUnit == .lines ? "linhas" : "px"
        return "\(scrollDirection.title) \(Int(scrollAmount)) \(unit)"
    }

    var hasScrollPosition: Bool {
        scrollX != 0 || scrollY != 0
    }

    var hasCoordinates: Bool {
        clickX != 0 || clickY != 0
    }

    var hasDragCoordinates: Bool {
        dragStartX != 0 || dragStartY != 0 || dragEndX != 0 || dragEndY != 0
    }

    /// Whether this step can be visualized on screen in debug mode (clicks, drags, scroll, window focus).
    var supportsDebugPreview: Bool {
        switch kind {
        case .click: return hasCoordinates
        case .dragAndDrop: return hasDragCoordinates
        case .scroll: return true
        case .launchApp: return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default: return false
        }
    }

    /// A human-readable reason this step is not ready to run, or nil when it is fully configured.
    /// Used to stop a run with a clear message instead of, e.g., silently clicking at (0,0).
    var configurationIssue: String? {
        switch kind {
        case .click:
            return hasCoordinates ? nil : "clique sem posição capturada"
        case .dragAndDrop:
            return hasDragCoordinates ? nil : "arrasto sem trajeto capturado"
        case .keyShortcut:
            return value.trimmingCharacters(in: .whitespaces).isEmpty ? "atalho não definido" : nil
        case .typeText:
            return value.isEmpty ? "texto vazio" : nil
        case .launchApp:
            return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "janela não selecionada" : nil
        case .randomNumber:
            return randomMin > randomMax ? "mínimo maior que o máximo" : nil
        case .scroll, .delay:
            return nil
        }
    }

    var isConfigured: Bool { configurationIssue == nil }
}

extension MacroStep {
    func copyWithNewID() -> MacroStep {
        var copy = MacroStep(kind: kind)
        copy.value = value
        copy.delay = delay
        copy.clickX = clickX
        copy.clickY = clickY
        copy.dragStartX = dragStartX
        copy.dragStartY = dragStartY
        copy.dragEndX = dragEndX
        copy.dragEndY = dragEndY
        copy.scrollDirection = scrollDirection
        copy.scrollAmount = scrollAmount
        copy.scrollMovesMouse = scrollMovesMouse
        copy.scrollX = scrollX
        copy.scrollY = scrollY
        copy.scrollUnit = scrollUnit
        copy.scrollStepDelayMs = scrollStepDelayMs
        copy.textMode = textMode
        copy.randomMin = randomMin
        copy.randomMax = randomMax
        return copy
    }

    mutating func setClickPoint(_ point: CGPoint) {
        clickX = point.x
        clickY = point.y
        value = "(\(Int(point.x)), \(Int(point.y)))"
    }
}

extension MacroStep {
    static func shortcut(_ value: String) -> MacroStep {
        var step = MacroStep(kind: .keyShortcut)
        step.value = value
        return step
    }
}

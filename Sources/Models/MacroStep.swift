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

    enum CodingKeys: String, CodingKey {
        case id, kind, value, delay, clickX, clickY
        case dragStartX, dragStartY, dragEndX, dragEndY
        case scrollDirection, scrollAmount, scrollMovesMouse, scrollX, scrollY, scrollUnit, scrollStepDelayMs
        case textMode
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
}

extension MacroStep {
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

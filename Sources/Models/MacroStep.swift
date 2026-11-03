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
    }

    var hasCoordinates: Bool {
        clickX != 0 || clickY != 0
    }

    var hasDragCoordinates: Bool {
        dragStartX != 0 || dragStartY != 0 || dragEndX != 0 || dragEndY != 0
    }
}

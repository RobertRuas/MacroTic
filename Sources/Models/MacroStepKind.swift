import SwiftUI

enum MacroStepKind: String, CaseIterable, Identifiable, Codable {
    case keyShortcut
    case typeText
    case click
    case delay
    case launchApp
    case openURL
    case dragAndDrop
    case scroll

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keyShortcut: "Atalho de teclado"
        case .typeText: "Digitar texto"
        case .click: "Clique"
        case .delay: "Esperar"
        case .launchApp: "Abrir app"
        case .openURL: "Abrir URL"
        case .dragAndDrop: "Clicar, arrastar e soltar"
        case .scroll: "Scroll"
        }
    }

    var icon: String {
        switch self {
        case .keyShortcut: "keyboard"
        case .typeText: "text.cursor"
        case .click: "cursorarrow.click"
        case .delay: "clock"
        case .launchApp: "app.badge"
        case .openURL: "link"
        case .dragAndDrop: "arrow.up.and.down.and.arrow.left.and.right"
        case .scroll: "scroll"
        }
    }

    var tint: Color {
        switch self {
        case .keyShortcut: .purple
        case .typeText: .blue
        case .click: .green
        case .delay: .orange
        case .launchApp: .pink
        case .openURL: .teal
        case .dragAndDrop: .indigo
        case .scroll: .cyan
        }
    }

    var placeholder: String {
        switch self {
        case .keyShortcut: "Pressione o atalho..."
        case .typeText: "Texto a digitar"
        case .click: "Clique para capturar posição"
        case .delay: ""
        case .launchApp: "Selecionar janela"
        case .openURL: "https://"
        case .dragAndDrop: "Clique e arraste na tela"
        case .scroll: ""
        }
    }

    var usesDelay: Bool { self == .delay }

    var usesCoordinates: Bool { self == .click }

    var usesDragCoordinates: Bool { self == .dragAndDrop }

    var usesScroll: Bool { self == .scroll }

    var usesShortcutRecorder: Bool { self == .keyShortcut }

    var usesWindowPicker: Bool { self == .launchApp }

    var usesTextField: Bool { self == .typeText || self == .openURL }
}

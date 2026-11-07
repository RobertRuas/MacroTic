import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case home
    case settings
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Início"
        case .settings: "Configurações"
        case .manual: "Manual"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .settings: "gearshape"
        case .manual: "questionmark.circle"
        }
    }
}

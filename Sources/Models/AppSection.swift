import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case home
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Início"
        case .settings: "Configurações"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .settings: "gearshape"
        }
    }
}

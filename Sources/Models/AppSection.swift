import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case home
    case testLab
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .testLab: "Testes"
        case .home: "Início"
        case .settings: "Configurações"
        }
    }

    var icon: String {
        switch self {
        case .testLab: "testtube.2"
        case .home: "house"
        case .settings: "gearshape"
        }
    }
}

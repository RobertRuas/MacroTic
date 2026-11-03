import SwiftUI

struct MainWindowView: View {
    let state: AppState

    var body: some View {
        NavigationSplitView {
            List(
                AppSection.allCases,
                selection: Binding(
                    get: { state.selectedSection },
                    set: { state.selectedSection = $0 }
                )
            ) { section in
                Label(section.title, systemImage: section.icon)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 280)
        } detail: {
            switch state.selectedSection {
            case .settings: SettingsView(state: state)
            default: Color.clear
            }
        }
    }
}

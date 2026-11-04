import SwiftUI

struct MainWindowView: View {
    let state: AppState

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                splitView
                StatusBarView {
                    StatusBarItem(
                        icon: "arrow.up.left.and.arrow.down.right",
                        "\(Int((proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing).rounded())) × \(Int((proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom).rounded())) px"
                    )
                }
            }
        }
    }

    private var splitView: some View {
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
            case .home: HomeView(state: state)
            default: Color.clear
            }
        }
    }
}

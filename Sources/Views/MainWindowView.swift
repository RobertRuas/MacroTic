import SwiftUI

struct MainWindowView: View {
    let state: AppState

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                content
                StatusBarView {
                    StatusBarItem(
                        icon: "arrow.up.left.and.arrow.down.right",
                        "\(Int((proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing).rounded())) × \(Int((proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom).rounded())) px"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state.selectedSection {
        case .settings: SettingsView(state: state, onClose: { state.selectedSection = .home })
        case .manual: ManualView(state: state, onClose: { state.selectedSection = .home })
        default: HomeView(state: state)
        }
    }
}

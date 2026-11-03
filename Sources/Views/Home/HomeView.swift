import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack(spacing: 14) {
            ActionsRow()
            MacroListView()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

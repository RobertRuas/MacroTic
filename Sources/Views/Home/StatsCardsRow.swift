import SwiftUI

struct ActionsRow: View {
    var body: some View {
        HStack(spacing: 10) {
            ActionCardView(
                title: "Nova Macro",
                icon: "plus.rectangle",
                color: .blue,
                action: {}
            )
            ActionCardView(
                title: "Inspetor",
                icon: "eye",
                color: .orange,
                action: {}
            )
            ActionCardView(
                title: "Gravar Ações",
                icon: "record.circle",
                color: .red,
                action: {}
            )
        }
    }
}

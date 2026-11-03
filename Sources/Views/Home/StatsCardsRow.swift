import SwiftUI

struct ActionsRow: View {
    let onNewMacro: () -> Void
    let onInspector: () -> Void
    let onRecord: () -> Void
    let isRecording: Bool
    let isInspectorActive: Bool

    var body: some View {
        HStack(spacing: 10) {
            ActionCardView(
                title: "Nova Macro",
                icon: "plus.rectangle",
                color: .blue,
                action: onNewMacro
            )
            ActionCardView(
                title: "Inspetor",
                icon: "eye",
                color: isInspectorActive ? .green : .orange,
                isActive: isInspectorActive,
                action: onInspector
            )
            ActionCardView(
                title: isRecording ? "Parar Gravação" : "Gravar Ações",
                icon: isRecording ? "stop.circle.fill" : "record.circle",
                color: .red,
                isActive: isRecording,
                action: onRecord
            )
        }
    }
}

import SwiftUI

struct IconActionButtonStyle: ButtonStyle {
    var tint: Color = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(tint.opacity(configuration.isPressed ? 0.28 : 0))
            )
            .scaleEffect(configuration.isPressed ? 0.80 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .animation(.spring(response: 0.22, dampingFraction: 0.45), value: configuration.isPressed)
    }
}

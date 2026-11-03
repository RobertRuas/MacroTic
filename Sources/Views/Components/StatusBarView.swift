import SwiftUI

struct StatusBarView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                content
                Spacer(minLength: 0)
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .frame(height: 22)
            .background(.bar)
        }
    }
}

struct StatusBarItem: View {
    let icon: String?
    let text: String

    init(icon: String? = nil, _ text: String) {
        self.icon = icon
        self.text = text
    }

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
            }
            Text(text)
                .monospacedDigit()
        }
        .padding(.trailing, 10)
        .overlay(alignment: .trailing) {
            Divider().padding(.vertical, 4)
        }
        .padding(.trailing, 10)
    }
}

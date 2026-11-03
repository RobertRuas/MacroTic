import SwiftUI

struct MacroRowView: View {
    let name: String
    let description: String
    let lastUsed: String
    let executionCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "command.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(executionCount)x")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(lastUsed)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
    }
}

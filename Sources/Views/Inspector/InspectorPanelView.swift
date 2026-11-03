import SwiftUI

struct InspectorPanelView: View {
    let inspector: InspectorState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(inspector.isActive ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(inspector.isActive ? "Rastreando" : "Inativo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("X")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("\(Int(inspector.mouseX))")
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.medium)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Y")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("\(Int(inspector.mouseY))")
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.medium)
                }

                Spacer()
            }

            HStack {
                Text("\(Int(inspector.mouseX)), \(Int(inspector.mouseY))")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    let str = "\(Int(inspector.mouseX)), \(Int(inspector.mouseY))"
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(str, forType: .string)
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Copiar coordenadas")
            }
        }
        .padding(12)
        .frame(width: 200)
    }
}

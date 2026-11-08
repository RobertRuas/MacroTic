import SwiftUI

struct ExecutionHUDView: View {
    let executor: MacroExecutor

    private var statusLine: String {
        if case .running(let step, let total) = executor.state {
            if executor.totalRepetitions > 1 {
                return "Rep \(executor.currentRepetition)/\(executor.totalRepetitions) · passo \(step + 1)/\(total)"
            }
            return "Passo \(step + 1) de \(total)"
        }
        return "Preparando…"
    }

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)

            VStack(alignment: .leading, spacing: 1) {
                Text("Executando macro")
                    .font(.caption.weight(.semibold))
                Text(statusLine)
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            HStack(spacing: 5) {
                Image(systemName: "stop.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
                Text("⌘Esc para parar")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.red.opacity(0.12), in: Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 320, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
    }
}

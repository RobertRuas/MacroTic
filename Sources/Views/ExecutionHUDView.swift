import SwiftUI

struct ExecutionHUDView: View {
    let executor: MacroExecutor
    let onStop: () -> Void

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

            Button(action: onStop) {
                Label("Parar", systemImage: "stop.fill")
            }
            .controlSize(.small)
            .tint(.red)

            Text("⌘Esc")
                .font(.caption2)
                .foregroundStyle(.tertiary)
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

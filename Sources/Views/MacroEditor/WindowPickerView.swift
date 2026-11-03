import AppKit
import SwiftUI

struct WindowInfo: Identifiable, Hashable {
    let id: Int
    let name: String
    let ownerName: String
    let ownerPID: Int32

    var displayName: String {
        if name.isEmpty {
            return ownerName
        }
        return "\(ownerName) — \(name)"
    }
}

struct WindowPickerView: View {
    let selectedValue: Binding<String>
    let onDismiss: () -> Void

    private var windows: [WindowInfo] {
        fetchWindows()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Selecionar Janela")
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if windows.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "macwindow")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Nenhuma janela encontrada")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(windows) { win in
                            Button {
                                selectedValue.wrappedValue = win.displayName
                                onDismiss()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "macwindow")
                                        .foregroundStyle(.blue)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(win.ownerName)
                                            .font(.callout)
                                            .fontWeight(.medium)
                                        if !win.name.isEmpty {
                                            Text(win.name)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer()

                                    if selectedValue.wrappedValue == win.displayName {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                            .font(.caption)
                                    }
                                }
                                .contentShape(Rectangle())
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)

                            if win.id != windows.last?.id {
                                Divider().padding(.leading, 46)
                            }
                        }
                    }
                }
                .frame(maxHeight: 240)
            }
        }
        .frame(width: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

private func fetchWindows() -> [WindowInfo] {
    guard let windowList = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements],
        kCGNullWindowID
    ) as? [[String: Any]] else {
        return []
    }

    var seen = Set<String>()
    var results: [WindowInfo] = []

    for entry in windowList {
        guard let ownerName = entry[kCGWindowOwnerName as String] as? String,
              let windowID = entry[kCGWindowNumber as String] as? Int,
              let ownerPID = entry[kCGWindowOwnerPID as String] as? Int32,
              let layer = entry[kCGWindowLayer as String] as? Int,
              layer == 0
        else { continue }

        if ownerName == "MacroTic" || ownerName == "Window Server" { continue }

        let windowName = entry[kCGWindowName as String] as? String ?? ""
        let key = "\(ownerName)|\(windowName)"
        if seen.contains(key) { continue }
        seen.insert(key)

        results.append(WindowInfo(
            id: windowID,
            name: windowName,
            ownerName: ownerName,
            ownerPID: ownerPID
        ))
    }

    return results
}

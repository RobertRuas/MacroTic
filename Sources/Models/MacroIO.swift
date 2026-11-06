import AppKit
import UniformTypeIdentifiers

enum MacroIO {
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static func export(_ macro: Macro) {
        guard let data = try? encoder.encode(macro) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(sanitizedFileName(macro.name)).json"
        panel.title = "Exportar macro"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    static func importMacro(completion: @escaping (Macro) -> Void) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Importar macro"
        panel.begin { response in
            guard response == .OK, let url = panel.url, let data = try? Data(contentsOf: url) else { return }
            if let macro = try? decoder.decode(Macro.self, from: data) {
                DispatchQueue.main.async { completion(macro) }
            } else if let macros = try? decoder.decode([Macro].self, from: data), let first = macros.first {
                DispatchQueue.main.async { completion(first) }
            }
        }
    }

    private static func sanitizedFileName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "macro" : trimmed
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        return base.components(separatedBy: invalid).joined(separator: "-")
    }
}

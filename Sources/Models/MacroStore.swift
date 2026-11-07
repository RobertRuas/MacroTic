import Foundation

@Observable
final class MacroStore {
    var macros: [Macro] = []

    private let fileURL: URL

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

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MacroTic", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("macros.json")
        load()
    }

    func save(_ macro: Macro) {
        if let index = macros.firstIndex(where: { $0.id == macro.id }) {
            macros[index] = macro
        } else {
            macros.insert(macro, at: 0)
        }
        persist()
    }

    func delete(_ id: UUID) {
        macros.removeAll { $0.id == id }
        persist()
    }

    func markUsed(_ id: UUID) {
        guard let index = macros.firstIndex(where: { $0.id == id }) else { return }
        macros[index].lastUsedAt = Date()
        macros[index].executionCount += 1
        persist()
    }

    func toggleFavorite(_ id: UUID) {
        guard let index = macros.firstIndex(where: { $0.id == id }) else { return }
        macros[index].isFavorite.toggle()
        persist()
    }

    /// All macros, favorites first, each group keeping its existing (newest-first) order.
    var sorted: [Macro] {
        let favorites = macros.filter { $0.isFavorite }
        let rest = macros.filter { !$0.isFavorite }
        return favorites + rest
    }

    // MARK: - Export / Import

    func exportJSON() -> Data? {
        try? Self.encoder.encode(macros)
    }

    /// Imports macros, skipping any whose id already exists. Returns how many were added and skipped.
    @discardableResult
    func importJSON(from data: Data) throws -> (imported: Int, skipped: Int) {
        let incoming = try Self.decoder.decode([Macro].self, from: data)
        var imported = 0
        var skipped = 0
        for macro in incoming {
            if macros.contains(where: { $0.id == macro.id }) {
                skipped += 1
            } else {
                macros.append(macro)
                imported += 1
            }
        }
        persist()
        return (imported, skipped)
    }

    func exportURL() -> URL? {
        guard let data = exportJSON() else { return nil }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("MacroTic-export.json")
        try? data.write(to: tempURL)
        return tempURL
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            macros = try Self.decoder.decode([Macro].self, from: data)
        } catch {
            // The file exists but could not be decoded. Preserve it before any later save()
            // overwrites it, so the user's macros stay recoverable instead of being silently lost.
            macros = []
            guard !data.isEmpty else { return }
            let backupURL = fileURL.deletingLastPathComponent()
                .appendingPathComponent("macros.corrupt-\(Int(Date().timeIntervalSince1970)).json")
            try? data.write(to: backupURL, options: .atomic)
            AppLog.shared.error("Falha ao ler macros.json (\(error.localizedDescription)). Backup salvo em \(backupURL.lastPathComponent).")
        }
    }

    private func persist() {
        guard let data = try? Self.encoder.encode(macros) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

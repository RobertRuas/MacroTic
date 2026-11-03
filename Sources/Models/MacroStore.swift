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

    var recentlyUsed: [Macro] {
        macros
            .filter { $0.lastUsedAt != nil }
            .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
            .prefix(3)
            .map { $0 }
    }

    // MARK: - Export / Import

    func exportJSON() -> Data? {
        try? Self.encoder.encode(macros)
    }

    func importJSON(from data: Data) throws {
        let imported = try Self.decoder.decode([Macro].self, from: data)
        for macro in imported {
            if !macros.contains(where: { $0.id == macro.id }) {
                macros.append(macro)
            }
        }
        persist()
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
        macros = (try? Self.decoder.decode([Macro].self, from: data)) ?? []
    }

    private func persist() {
        guard let data = try? Self.encoder.encode(macros) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

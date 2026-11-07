import Foundation

/// Lightweight persistent logger. Writes to ~/Library/Logs/MacroTic/MacroTic.log,
/// tees stderr into the same file (so runtime/system errors are captured too), and
/// keeps the file bounded. The log file is what FeedbackMailer attaches to feedback e-mails.
final class AppLog {
    static let shared = AppLog()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.macrotic.applog")
    private let maxBytes = 256 * 1024 // keep the most recent ~256 KB
    private var originalStderr: Int32 = -1

    var logFileURL: URL { fileURL }

    private init() {
        let logsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/MacroTic", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        fileURL = logsDir.appendingPathComponent("MacroTic.log")
    }

    // MARK: - Bootstrap

    /// Call once, as early as possible at launch. Writes a session header and starts the stderr tee.
    func bootstrap() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        queue.async { [self] in
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            }
            trimIfNeeded()
        }
        log("===== Sessão iniciada — MacroTic v\(version) =====")
        teeStandardError()
    }

    // MARK: - Public logging

    func log(_ message: String, level: String = "INFO") {
        let line = "\(Self.timestamp()) [\(level)] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        append(data)
    }

    func error(_ message: String) { log(message, level: "ERROR") }

    /// The tail of the log, as text, for inline use (e.g. the mailto fallback body).
    func recentText(maxBytes: Int) -> String {
        queue.sync {
            guard let data = try? Data(contentsOf: fileURL) else { return "" }
            let slice = data.count > maxBytes ? data.suffix(maxBytes) : data
            return String(decoding: slice, as: UTF8.self)
        }
    }

    // MARK: - Internals

    private func append(_ data: Data) {
        queue.async { [self] in
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                handle.seekToEndOfFile()
                handle.write(data)
            } else {
                try? data.write(to: fileURL)
            }
            trimIfNeeded()
        }
    }

    /// Keeps only the last `maxBytes` of the file (trimmed to a line boundary). Runs on `queue`.
    private func trimIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? Int, size > maxBytes,
              var data = try? Data(contentsOf: fileURL) else { return }
        data = Data(data.suffix(maxBytes))
        if let newlineIndex = data.firstIndex(of: 0x0A), newlineIndex + 1 < data.count {
            data = Data(data[(newlineIndex + 1)...])
        }
        try? data.write(to: fileURL)
    }

    /// Redirects stderr through a pipe that writes to BOTH the real stderr and the log file,
    /// so NSLog/print-to-stderr and system error messages land in the log without losing the console.
    private func teeStandardError() {
        guard originalStderr == -1 else { return }
        originalStderr = dup(STDERR_FILENO)
        let pipe = Pipe()
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)
        let realStderr = originalStderr
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            data.withUnsafeBytes { raw in
                if let base = raw.baseAddress { _ = write(realStderr, base, data.count) }
            }
            self?.append(data)
        }
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static func timestamp() -> String { formatter.string(from: Date()) }
}

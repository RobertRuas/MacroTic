import CoreGraphics

enum ShortcutKeyMap {
    private struct Key {
        let code: CGKeyCode
        let display: String
        let aliases: [String]
    }

    private static let keys: [Key] = {
        var list: [Key] = []
        let letters: [(String, CGKeyCode)] = [
            ("A", 0), ("S", 1), ("D", 2), ("F", 3), ("H", 4), ("G", 5), ("Z", 6), ("X", 7),
            ("C", 8), ("V", 9), ("B", 11), ("Q", 12), ("W", 13), ("E", 14), ("R", 15),
            ("Y", 16), ("T", 17), ("O", 31), ("U", 32), ("I", 34), ("P", 35),
            ("L", 37), ("J", 38), ("K", 40), ("N", 45), ("M", 46),
        ]
        for (name, code) in letters { list.append(Key(code: code, display: name, aliases: [])) }

        let symbols: [(String, CGKeyCode)] = [
            ("1", 18), ("2", 19), ("3", 20), ("4", 21), ("6", 22), ("5", 23), ("=", 24),
            ("9", 25), ("7", 26), ("-", 27), ("8", 28), ("0", 29), ("]", 30), ("[", 33),
            ("'", 39), (";", 41), ("\\", 42), (",", 43), ("/", 44), (".", 47), ("`", 50),
        ]
        for (name, code) in symbols { list.append(Key(code: code, display: name, aliases: [])) }

        list += [
            Key(code: 36, display: "↩", aliases: ["return", "enter"]),
            Key(code: 76, display: "⌤", aliases: ["numpadenter"]),
            Key(code: 48, display: "⇥", aliases: ["tab"]),
            Key(code: 49, display: "Space", aliases: ["espaço", "espaco"]),
            Key(code: 51, display: "⌫", aliases: ["delete", "backspace"]),
            Key(code: 117, display: "⌦", aliases: ["forwarddelete"]),
            Key(code: 53, display: "⎋", aliases: ["escape", "esc"]),
            Key(code: 123, display: "←", aliases: ["left"]),
            Key(code: 124, display: "→", aliases: ["right"]),
            Key(code: 125, display: "↓", aliases: ["down"]),
            Key(code: 126, display: "↑", aliases: ["up"]),
            Key(code: 115, display: "Home", aliases: []),
            Key(code: 119, display: "End", aliases: []),
            Key(code: 116, display: "PgUp", aliases: ["pageup"]),
            Key(code: 121, display: "PgDn", aliases: ["pagedown"]),
            Key(code: 114, display: "Help", aliases: []),
        ]

        let functionKeys: [(Int, CGKeyCode)] = [
            (1, 122), (2, 120), (3, 99), (4, 118), (5, 96), (6, 97), (7, 98), (8, 100),
            (9, 101), (10, 109), (11, 103), (12, 111), (13, 105), (14, 107), (15, 113),
            (16, 106), (17, 64), (18, 79), (19, 80), (20, 90),
        ]
        for (n, code) in functionKeys { list.append(Key(code: code, display: "F\(n)", aliases: [])) }

        let keypad: [(String, CGKeyCode)] = [
            ("0", 82), ("1", 83), ("2", 84), ("3", 85), ("4", 86), ("5", 87),
            ("6", 88), ("7", 89), ("8", 91), ("9", 92),
        ]
        for (n, code) in keypad { list.append(Key(code: code, display: "Num\(n)", aliases: [])) }

        return list
    }()

    private static let byCode: [CGKeyCode: Key] = Dictionary(uniqueKeysWithValues: keys.map { ($0.code, $0) })

    private static let byName: [String: CGKeyCode] = {
        var map: [String: CGKeyCode] = [:]
        for key in keys {
            map[key.display.lowercased()] = key.code
            for alias in key.aliases { map[alias.lowercased()] = key.code }
        }
        return map
    }()

    static var allKeyNames: [String] { keys.map(\.display) }

    static func displayName(for code: CGKeyCode) -> String? {
        byCode[code]?.display
    }

    static func keyCode(for name: String) -> CGKeyCode? {
        byName[name.lowercased()]
    }

    static func modifierSymbols(for flags: CGEventFlags) -> String {
        var result = ""
        if flags.contains(.maskControl) { result += "⌃" }
        if flags.contains(.maskAlternate) { result += "⌥" }
        if flags.contains(.maskShift) { result += "⇧" }
        if flags.contains(.maskCommand) { result += "⌘" }
        return result
    }

    static func shortcutString(keyCode: CGKeyCode, flags: CGEventFlags) -> String {
        modifierSymbols(for: flags) + (displayName(for: keyCode) ?? "Key\(keyCode)")
    }

    static func parse(_ shortcut: String) -> (keyCode: CGKeyCode, flags: CGEventFlags)? {
        let trimmed = shortcut.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        var flags: CGEventFlags = []
        var tokens = trimmed.split(separator: "+", omittingEmptySubsequences: true).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        guard let last = tokens.popLast() else { return nil }

        for token in tokens {
            if let word = modifierWord(token) {
                flags.insert(word)
            } else {
                for ch in token { if let f = modifierSymbol(ch) { flags.insert(f) } }
            }
        }

        var keyName = Substring(last)
        while let first = keyName.first, let f = modifierSymbol(first), keyName.count > 1 {
            flags.insert(f)
            keyName = keyName.dropFirst()
        }

        let name = String(keyName)
        if name.lowercased().hasPrefix("key"), let raw = UInt16(name.dropFirst(3)) {
            return (CGKeyCode(raw), flags)
        }
        guard let code = keyCode(for: name) else { return nil }
        return (code, flags)
    }

    private static func modifierSymbol(_ ch: Character) -> CGEventFlags? {
        switch ch {
        case "⌘": .maskCommand
        case "⌥": .maskAlternate
        case "⇧": .maskShift
        case "⌃": .maskControl
        default: nil
        }
    }

    private static func modifierWord(_ word: String) -> CGEventFlags? {
        switch word.lowercased() {
        case "cmd", "command": .maskCommand
        case "opt", "option", "alt": .maskAlternate
        case "shift": .maskShift
        case "ctrl", "control": .maskControl
        default: nil
        }
    }
}

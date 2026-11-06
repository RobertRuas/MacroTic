import AppKit
import ApplicationServices

enum WindowCatalog {
    struct WindowRef {
        let title: String
        let appName: String
        let pid: pid_t
    }

    static func windows() -> [WindowRef] {
        var result: [WindowRef] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            guard let appName = app.localizedName, appName != "MacroTic" else { continue }
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            var windowsValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
                  let windows = windowsValue as? [AXUIElement] else { continue }
            for window in windows {
                var titleValue: CFTypeRef?
                guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success,
                      let rawTitle = titleValue as? String else { continue }
                let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { continue }
                result.append(WindowRef(title: title, appName: appName, pid: app.processIdentifier))
            }
        }
        return result
    }

    static func titles(including current: String = "") -> [String] {
        var seen = Set<String>()
        var list: [String] = []
        for window in windows() where seen.insert(window.title).inserted {
            list.append(window.title)
        }
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, seen.insert(trimmed).inserted {
            list.append(trimmed)
        }
        return list.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    static func window(forTitle title: String) -> WindowRef? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return windows().first { $0.title == trimmed }
    }

    /// Screen rect (CG top-left origin) of the window with this title, if currently open.
    static func frame(forTitle title: String) -> CGRect? {
        guard let ref = window(forTitle: title) else { return nil }
        let appElement = AXUIElementCreateApplication(ref.pid)
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else { return nil }
        for window in windows {
            var titleValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success,
                  let windowTitle = titleValue as? String,
                  windowTitle.trimmingCharacters(in: .whitespacesAndNewlines) == ref.title else { continue }

            var posValue: CFTypeRef?
            var sizeValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posValue) == .success,
                  AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
                  let posAX = posValue, CFGetTypeID(posAX) == AXValueGetTypeID(),
                  let sizeAX = sizeValue, CFGetTypeID(sizeAX) == AXValueGetTypeID() else { return nil }

            var point = CGPoint.zero
            var size = CGSize.zero
            AXValueGetValue(posAX as! AXValue, .cgPoint, &point)
            AXValueGetValue(sizeAX as! AXValue, .cgSize, &size)
            return CGRect(origin: point, size: size)
        }
        return nil
    }
}

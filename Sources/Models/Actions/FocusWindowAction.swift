import AppKit
import ApplicationServices

struct FocusWindowAction: MacroAction {
    func execute(step: MacroStep) async -> Bool {
        let title = step.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let target = WindowCatalog.window(forTitle: title) else { return false }

        let appElement = AXUIElementCreateApplication(target.pid)
        var windowsValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
           let windows = windowsValue as? [AXUIElement] {
            for window in windows {
                var titleValue: CFTypeRef?
                guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success,
                      let windowTitle = titleValue as? String,
                      windowTitle.trimmingCharacters(in: .whitespacesAndNewlines) == target.title else { continue }
                AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
                AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                break
            }
        }

        NSRunningApplication(processIdentifier: target.pid)?.activate()
        try? await Task.sleep(for: .milliseconds(300))
        return true
    }
}

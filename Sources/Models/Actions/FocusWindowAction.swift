import AppKit
import ApplicationServices

struct FocusWindowAction: MacroAction {
    func execute(step: MacroStep) async -> Bool {
        let title = step.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let target = WindowCatalog.window(forTitle: title) else { return false }

        let runningApp = NSRunningApplication(processIdentifier: target.pid)
        let appElement = AXUIElementCreateApplication(target.pid)

        func raiseMatchingWindow() {
            var windowsValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
                  let windows = windowsValue as? [AXUIElement] else { return }

            var matched: AXUIElement?
            for window in windows {
                var titleValue: CFTypeRef?
                if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success,
                   let windowTitle = titleValue as? String,
                   windowTitle.trimmingCharacters(in: .whitespacesAndNewlines) == target.title {
                    matched = window
                    break
                }
            }
            guard let window = matched ?? windows.first else { return }
            AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            AXUIElementSetAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, window)
        }

        // 1. Bring the owning application forward (both the AppKit and AX routes:
        //    AX frontmost is what actually wins when another app is currently active).
        runningApp?.activate(options: [.activateAllWindows])
        AXUIElementSetAttributeValue(appElement, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        try? await Task.sleep(for: .milliseconds(120))

        // 2. Raise the specific window within that app.
        raiseMatchingWindow()
        try? await Task.sleep(for: .milliseconds(120))

        // 3. Re-assert once the app has settled — the first activation can lose a
        //    focus race against the previously-frontmost app letting go.
        AXUIElementSetAttributeValue(appElement, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        raiseMatchingWindow()
        try? await Task.sleep(for: .milliseconds(150))
        return true
    }
}

# MacroTic — File & Directory Map

> Reference for AI agents. Every file and directory in this project with its exact purpose, contents, and relationships.

## Project Overview

- **What**: Native macOS app — macro automation tool. Classic window with sidebar navigation, Home screen (macro list + creation), and Settings screen.
- **Stack**: Swift 6.4, SwiftUI + AppKit hybrid, Swift Package Manager (no Xcode project)
- **Target**: macOS 26+
- **Language mode**: Swift 5 (SwiftUIMacros plugin is NOT available — `@State`, `@Binding`, `@Environment` cannot be used)
- **Observation**: Uses `@Observable` (ObservationMacros IS available). Bindings are created manually via `Binding(get:set:)`.
- **Dock icon**: `.regular` activation policy. Closing the window quits the app (`applicationShouldTerminateAfterLastWindowClosed`).

---

## Root Files

```
MacroTic/
├── Package.swift              SPM manifest. swift-tools-version:6.2, target macOS .v26, language mode .v5. Single executable target "MacroTic" with path "Sources". Depends on sparkle-project/Sparkle (from 2.6.4). linkerSettings add -rpath @executable_path and @executable_path/../Frameworks so the Sparkle.framework resolves both from .build/debug (local dev) and from Contents/Frameworks (packaged .app).
├── Package.resolved           Pins the resolved Sparkle version. Scripts/build_appcast.sh and Scripts/generate_sparkle_keys.sh read this to download matching Sparkle CLI tools.
├── dev.sh                     Hot reload script. On start, kills any already-running MacroTic instance (even from a previous/untracked session) before the first build. Uses fswatch to watch Sources/ recursively. On file change: kills running app → swift build → relaunch. Run with: bash dev.sh
├── .gitignore                 Ignores .build/, .swiftpm/, xcodeproj, DerivedData, .DS_Store, build/, dist/, .sparkle-tools/
└── AI_PROJECT_MAP.md          THIS FILE. Project map for AI agents.
```

## Releases & Auto-Update

```
.github/workflows/
└── release.yml                Triggers on push of tags matching v*.*.*. Builds release binary, packages MacroTic.app
                                (via Scripts/package_app.sh), signs it for Sparkle and generates the appcast
                                (via Scripts/build_appcast.sh), creates a GitHub Release with the .zip + appcast.xml,
                                then deletes every other release so only the latest stays published.
                                Needs repo secrets: SPARKLE_PRIVATE_KEY, SPARKLE_PUBLIC_KEY (see Scripts/generate_sparkle_keys.sh).

Packaging/
└── Info.plist                 Template Info.plist for the packaged app. Placeholders __VERSION__, __OWNER__, __REPO__,
                                __SPARKLE_PUBLIC_KEY__ are substituted by Scripts/package_app.sh.
                                SUFeedURL points to https://github.com/<owner>/<repo>/releases/latest/download/appcast.xml
                                (GitHub's stable "latest" redirect — always resolves to the one release kept published).
                                SUEnableAutomaticChecks + SUAutomaticallyUpdate are both true: updates download and
                                install automatically without prompting.

Scripts/
├── package_app.sh              Builds build/MacroTic.app from .build/release, embeds Sparkle.framework into
│                                Contents/Frameworks, fills in Packaging/Info.plist, ad-hoc codesigns (deep, including
│                                Sparkle's nested XPC services/Autoupdate/Updater.app), zips to dist/MacroTic-<version>.zip.
├── build_appcast.sh             Downloads the Sparkle CLI tools matching Package.resolved's pinned version, runs
│                                generate_appcast against dist/ to sign the zip (EdDSA) and emit dist/appcast.xml.
│                                Reads the private key from SPARKLE_PRIVATE_KEY (never written to disk outside a temp file).
└── generate_sparkle_keys.sh     Run locally (not in CI) once to generate the Sparkle EdDSA key pair via the official
                                 generate_keys tool. Private key goes to the login Keychain / GitHub secret
                                 SPARKLE_PRIVATE_KEY; public key goes into Packaging/Info.plist and GitHub secret
                                 SPARKLE_PUBLIC_KEY.
```

No code signing certificate / Apple Developer ID is configured yet — builds are ad-hoc signed only, so
first launch after download/update will show a Gatekeeper warning until a Developer ID is added later.

## Config

```
.vscode/
└── launch.json                VS Code Swift debugger configs (Debug + Release). Uses swift-extension launch type.
```

---

## Sources — Application Code

All Swift source files live under `Sources/`. SPM compiles every `.swift` file as a single target.

```
Sources/
├── App/
│   ├── MacroTicApp.swift          ENTRY POINT. @main enum MacroTicApp; AppDelegate creates MainWindowController
│   │                              and quits when the last window closes.
│   ├── MainWindowController.swift Creates the classic NSWindow (titled, closable, miniaturizable, resizable,
│   │                              720x480, min 560x380, centered, zoom/maximize disabled) hosting MainWindowView. Owns AppState.
│   └── UpdaterController.swift    SPARKLE WRAPPER. @Observable class around SPUStandardUpdaterController; starts on init.
│                                  Behavior comes from Contents/Info.plist (see Packaging/Info.plist). No-op outside a packaged .app.
├── Models/
│   ├── AppSection.swift           Sidebar entries (enum: id, title, icon). Add a case to add a sidebar row.
│   ├── AppState.swift             @Observable: selectedSection, updater, isCreatingMacro flag + macroDraft, macroStore, macroExecutor, actionRecorder, inspectorState, inspectorPanel. Methods: beginCreatingMacro(), saveMacro(), playMacro(), stopMacro(), toggleInspector(), startRecording(), stopRecording().
│   ├── Macro.swift                Domain model (struct, Codable): id, name, details, iconName, steps:[MacroStep], createdAt, lastUsedAt, executionCount. Provides lastUsedLabel computed property. The finished macro a MacroDraft produces.
│   ├── MacroExecutor.swift        @Observable execution engine. Runs macro steps sequentially using CGEvent (keyboard/mouse), NSWorkspace (apps/URLs). Tracks state (idle/running/paused/finished/error). Methods: execute(), pause(), resume(), stop(). Supports all MacroStepKind types.
│   ├── ActionRecorder.swift       @Observable action recorder. Uses CGEvent tap (listenOnly) to capture clicks, keystrokes, scroll events into MacroStep array. Auto-inserts delay steps between actions. Methods: startRecording(), stopRecording(), makeDraft(). Produces a MacroDraft ready for editing.
│   ├── InspectorState.swift       @Observable real-time mouse coordinate tracker. Uses NSEvent global monitor + timer to track mouseX/mouseY (in CGEvent coordinate space). Methods: start(), stop(), toggle().
│   ├── MacroStore.swift           @Observable JSON persistence layer. Saves/loads macros to ~/Library/Application Support/MacroTic/macros.json. Methods: save, delete, markUsed, exportJSON, importJSON, exportURL. Provides recentlyUsed (top 3).
│   ├── MacroStep.swift            One step in a macro (struct): id, kind, value, delay, clickX/clickY (for .click), dragStartX/Y + dragEndX/Y (for .dragAndDrop), scrollDirection + scrollAmount (for .scroll). Also defines ScrollDirection enum.
│   ├── MacroStepKind.swift        Step types (enum: keyShortcut, typeText, click, delay, launchApp, openURL, dragAndDrop, scroll). Each provides title, icon, tint color, placeholder, and boolean flags: usesDelay, usesCoordinates, usesDragCoordinates, usesScroll, usesShortcutRecorder, usesWindowPicker, usesTextField.
│   └── MacroDraft.swift           @Observable editor/form state for building a macro: name, details, iconName, steps, selectedStepID + add/remove/moveUp/moveDown/moveSelectedUp/moveSelectedDown, isValid, makeMacro(). Retained on AppState so edits survive view re-renders.
└── Views/
    ├── MainWindowView.swift       NavigationSplitView: sidebar List of AppSection (bound to state.selectedSection); detail shows HomeView(state:) for .home, SettingsView for .settings, empty otherwise.
    ├── MacroEditor/
    │   ├── CreateMacroView.swift      MACRO CREATION SCREEN. Shown as a .sheet from HomeView (580x520). Form over a MacroDraft: Identificação card (name + description) + Ações card (ordered step rows with selection highlight, "Adicionar" Menu listing all MacroStepKind, empty state) + footer (step count, Cancelar, Salvar). Keyboard shortcuts: ⌘↑/⌘↓ move selected step. Animated transitions on add/remove/reorder.
    │   ├── MacroStepRowView.swift     One editable step row: colored kind icon, numbered title, specialized inline editor per kind (KeyShortcutRecorder for shortcuts, ScreenCoordinatePicker for click/drag, WindowPickerView for apps, Picker+Slider for scroll, TextField for text/URL, Slider for delay), selection highlight, and move-up/move-down/delete controls.
    │   ├── ScreenCoordinatePicker.swift  AppKit overlay (NSPanel) for capturing screen coordinates. Single-click mode for .click steps; fluid click-drag-release mode for .dragAndDrop steps. Shows crosshair cursor, instruction HUD, markers (A/B) and dashed drag line.
    │   ├── KeyShortcutRecorder.swift   NSViewRepresentable keyboard shortcut recorder. Captures modifier+key combos interactively. Displays human-readable symbols (⌘⌥⇧⌃ + key names).
    │   └── WindowPickerView.swift     Floating panel listing open windows (via CGWindowListCopyWindowInfo). Filters out MacroTic and Window Server. Shows owner app + window title for selection.
    ├── Inspector/
    │   ├── InspectorPanelController.swift  AppKit NSPanel controller for the floating inspector. Shows/hides the panel, positions it top-right. Owns InspectorState lifecycle (start/stop on show/close).
    │   └── InspectorPanelView.swift   SwiftUI content for the inspector panel: live X/Y coordinates (monospaced), active/inactive indicator, copy-to-clipboard button.
    ├── Home/
    │   ├── HomeView.swift             HOME SCREEN. Takes AppState. Composes ActionsRow (top) + execution banner (when running) + MacroListView (bottom). Hosts CreateMacroView .sheet. Wires all three action cards: Nova Macro, Inspetor, Gravar Ações.
    │   ├── StatsCardView.swift        ActionCardView component: clickable card with icon, title, color, optional isActive state (pulse animation + tinted background). Used by ActionsRow.
    │   ├── StatsCardsRow.swift        ActionsRow: horizontal row of ActionCardView cards. All three wired: Nova Macro (opens create sheet), Inspetor (toggles floating panel), Gravar Ações (starts/stops recording). Shows active states.
    │   ├── MacroListView.swift        Takes MacroStore + MacroExecutor. Two sections: "Usados Recentemente" (top 3) and "Todas as Macros". Each row has play/stop buttons. Context menu with execute + delete.
    │   └── MacroRowView.swift         Single macro row: icon, name, details, play/stop button, executionCount, lastUsedLabel, step count badge. Context menu: Executar + Apagar.
    └── Settings/
        └── SettingsView.swift     SETTINGS SCREEN. Single "Atualizações" card: current version (CFBundleShortVersionString) + "Verificar atualizações" button (state.updater.checkForUpdates()).
```

## Key Architecture Decisions

| Decision | Reason |
|---|---|
| `@Observable` instead of `ObservableObject` | `ObservableObject` uses `@Published` which works, but `@Observable` is the modern pattern and ObservationMacros plugin IS available in Command Line Tools |
| No `@State`, `@Binding`, `@Environment` | SwiftUIMacros plugin is missing from Command Line Tools (only available with full Xcode). All local state lives in `@Observable` classes. Bindings use `Binding(get:set:)` |
| `NSWindow` instead of `WindowGroup` | The app is started from a custom `main` with AppKit; the window is created manually |
| `NSHostingView` bridge | Hosts SwiftUI views inside the AppKit NSWindow. SwiftUI handles all UI rendering |
| `.regular` activation policy | Dock icon shown while the app runs |
| `swift-tools-version:6.2` | Required for `.macOS(.v26)` platform target |
| `.swiftLanguageMode(.v5)` | Avoids Swift 6 strict concurrency requirements while using 6.2 toolchain |
| `fswatch` for hot reload | Lightweight file watcher (Homebrew). Monitors Sources/ and triggers rebuild+relaunch |
| Sparkle for auto-update | De facto standard for non-App-Store macOS apps. Handles update checks, EdDSA-verified downloads, and silent install (SUAutomaticallyUpdate) |
| GitHub Releases "latest" redirect as feed URL | `releases/latest/download/appcast.xml` never changes, so Info.plist's SUFeedURL is static even though old releases get deleted on every tag push |
| Ad-hoc codesign only (no Developer ID yet) | No Apple Developer account configured. First launch after install/update shows a Gatekeeper warning until a Developer ID + notarization is added |
| JSON file for macro persistence | Macros saved as pretty-printed JSON at `~/Library/Application Support/MacroTic/macros.json`. Human-readable, easy to export/import. All models are `Codable` with ISO 8601 dates |
| Interactive action editors per step kind | Each MacroStepKind uses a specialized editor: screen overlay for click/drag coordinates, NSView-based shortcut recorder for keyboard shortcuts, CGWindowList for window picker, Picker+Slider for scroll. No generic text fields for structured data |
| CGEvent for macro execution | MacroExecutor uses CGEvent API to post keyboard, mouse, and scroll events at the HID system tap level. Requires Accessibility permission in System Settings |
| CGEvent tap for action recording | ActionRecorder uses a listenOnly CGEvent tap (cgSessionEventTap) to capture user input without blocking events. Also requires Accessibility permission |
| NSPanel for inspector | Inspector uses a floating NSPanel (utilityWindow + nonactivatingPanel) that stays above all windows and doesn't steal focus. Tracks mouse via NSEvent global monitor |

---

## Build & Run

```bash
swift build                    # compile
.build/debug/MacroTic          # run directly
bash dev.sh                    # hot reload (watch + rebuild + relaunch)

# Release packaging (normally done by .github/workflows/release.yml on a tag push):
swift build -c release
APP_VERSION=1.0.0 APP_OWNER=<owner> APP_REPO=<repo> SPARKLE_PUBLIC_KEY=<key> bash Scripts/package_app.sh
SPARKLE_PRIVATE_KEY=<key> bash Scripts/build_appcast.sh   # signs dist/*.zip, writes dist/appcast.xml

# One-time, local only (writes to your login Keychain, never run in CI):
bash Scripts/generate_sparkle_keys.sh
```

## Conventions

- **One responsibility per file** — each file contains a single struct/class/enum
- **Views** — SwiftUI views go in Views/
- **Models** — observable state and data types go in Models/
- **No comments in code** — code is self-documenting; this map file is the reference

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
│   │                              1040x700, min 820x520, centered, zoom/maximize disabled) hosting MainWindowView. Owns AppState.
│   └── UpdaterController.swift    SPARKLE WRAPPER. @Observable class around SPUStandardUpdaterController; starts on init.
│                                  Behavior comes from Contents/Info.plist (see Packaging/Info.plist). No-op outside a packaged .app.
├── Models/
│   ├── AppSection.swift           Sidebar entries (enum: id, title, icon). Add a case to add a sidebar row.
│   ├── AppState.swift             @Observable: selectedSection, updater, isCreatingMacro flag + macroDraft + editingMacroID, macroStore, macroExecutor, actionRecorder, inspectorState, inspectorPanel. Methods: beginCreatingMacro(), beginEditingMacro(), saveMacro() (handles create vs edit), deleteMacro() (animated), playMacro(), stopMacro(), toggleInspector(), startRecording(), stopRecording().
│   ├── Macro.swift                Domain model (struct, Codable): id, name, details, iconName, steps:[MacroStep], intervalBetweenSteps (default 0.5s), repeatCount (default 1, executor repeats the whole sequence), createdAt, lastUsedAt, executionCount. Provides createdAtLabel (dd/MM/yyyy HH:mm) and lastUsedLabel computed properties. Backwards-compatible Codable (decodeIfPresent for intervalBetweenSteps).
│   ├── MacroExecutor.swift        @Observable orchestrator. Delegates each step to the matching MacroAction from Actions/. Runs on Task.detached (background), updates state on MainActor. Waits intervalBetweenSteps between each step. Tracks state (idle/running/paused/finished/error). Restores the cursor to its original position when the macro ends/stops. On finish/error/stop calls activateApp() to bring MacroTic's window back to the front. ⌘Esc (global + local key monitor, installed while running) stops the macro. Methods: execute(), pause(), resume(), stop().
│   ├── Actions/
│   │   ├── MacroAction.swift          Protocol: `execute(step:) -> Bool`. All action types conform to this.
│   │   ├── KeyShortcutAction.swift    Parses step.value via ShortcutKeyMap, presses modifier keys (flagsChanged), posts key down/up, releases modifiers.
│   │   ├── TypeTextAction.swift       step.textMode: .typing = char-by-char CGEvent unicode injection; .paste = sets pasteboard, sends ⌘V, restores previous clipboard.
│   │   ├── ClickAction.swift          Moves cursor to step.clickX/clickY, posts mouseDown/mouseUp with timing gaps.
│   │   ├── DelayAction.swift          Sleeps for step.delay seconds (edited in milliseconds in the UI).
│   │   ├── FocusWindowAction.swift    Brings the window named by step.value (a window title) to the front. Resolves the title via WindowCatalog to its owner PID, then uses the Accessibility API (AXWindows → match kAXTitle → set kAXMain + kAXRaiseAction) to raise that specific window, and activates the owning app.
│   │   ├── DragAndDropAction.swift    Smoothstep-eased drag from start to end coordinates (30 interpolation steps).
│   │   └── ScrollAction.swift         Optionally moves the mouse to step.scrollX/Y first (scrollMovesMouse): zeroes the event source's localEventsSuppressionInterval and waits 300ms so the warp settles before scrolling (otherwise early events route to the old cursor location). Then scrolls deterministically via a single scroll(unit:perEvent:delayMs:) loop that posts small uniform deltas until the exact total is reached — NO scroll-phase/momentum emulation (phases caused inconsistent inertia across apps). .lines = 1 line per event every 25ms; .pixels = 10px per event every 8ms with scrollWheelEventIsContinuous set.
│   ├── ActionRecorder.swift       @Observable action recorder. Uses CGEvent tap (listenOnly) to capture clicks, keystrokes, scroll events into MacroStep array. Auto-inserts delay steps between actions. Methods: startRecording(), stopRecording(), makeDraft(). Produces a MacroDraft ready for editing.
│   ├── ActionTester.swift         @Observable engine of the Test Lab. Holds standalone test steps, countdown, interval, hide-app option, result log. Runs a single step or all in sequence using MacroExecutor.actions (same code path as real macros). Adding a .click step auto-opens the crosshair picker (same in MacroDraft.add). Methods: addStep, removeStep, duplicateStep, moveUp/moveDown, test(_:), testAll(), cancel(), clearLog(). Lives on AppState.actionTester.
│   ├── ShortcutKeyMap.swift       Single source of truth for shortcut strings (e.g. "⌘⇧C"): key code ↔ name tables, modifier symbols, parse() (also accepts legacy "⌘+c" / "cmd+Return"). Used by KeyShortcutAction and ShortcutCapturePicker.
│   ├── WindowCatalog.swift        Lists currently open windows via the Accessibility API (AXWindows of every regular running app, excluding MacroTic), each identified by its window title. titles() → sorted unique titles for the "Selecionar janela" dropdown; window(forTitle:) resolves a title back to its owner PID for FocusWindowAction. Queried live (no cache / refresh).
│   ├── TestLogEntry.swift         One test result row: time, kind, detail, success, duration.
│   ├── InspectorState.swift       @Observable real-time mouse coordinate tracker. Uses NSEvent global monitor + timer to track mouseX/mouseY (in CGEvent coordinate space). Methods: start(), stop(), toggle().
│   ├── MacroStore.swift           @Observable JSON persistence layer. Saves/loads macros to ~/Library/Application Support/MacroTic/macros.json. Methods: save, delete, markUsed, exportJSON, importJSON, exportURL. Provides recentlyUsed (top 3).
│   ├── MacroStep.swift            One step in a macro (struct, custom backwards-compatible decode): id, kind, value, delay, textMode (TextInputMode), scrollMovesMouse + scrollX/Y + scrollUnit (lines/pixels) + scrollStepDelayMs, clickX/clickY (for .click), dragStartX/Y + dragEndX/Y (for .dragAndDrop), scrollDirection + scrollAmount (for .scroll). Also defines ScrollDirection enum.
│   ├── MacroStepKind.swift        Step types (enum: keyShortcut, typeText, click, delay, launchApp, dragAndDrop, scroll; openURL was removed — legacy steps are dropped on load via Macro's lossy decode). Each provides title, icon, tint color, placeholder, and boolean flags: usesDelay, usesCoordinates, usesDragCoordinates, usesScroll, usesShortcutRecorder, usesWindowPicker, usesTextField.
│   └── MacroDraft.swift           @Observable editor/form state for building a macro: name, details, iconName, steps, intervalBetweenSteps, selectedStepID + add/remove/moveUp/moveDown/moveSelectedUp/moveSelectedDown, isValid, loadFrom(Macro), makeMacro(), makeMacro(preservingID:). Retained on AppState so edits survive view re-renders.
└── Views/
    ├── MainWindowView.swift       Wraps everything in a GeometryReader: NavigationSplitView above + StatusBarView below showing the current window size ("W × H px", includes safe-area insets so it equals the window content size). NavigationSplitView: sidebar List of AppSection (bound to state.selectedSection); detail shows HomeView(state:) for .home, SettingsView for .settings, empty otherwise.
    ├── Components/
    │   ├── StatusBarView.swift  Classic bottom status bar. StatusBarView { content } = top divider + 22pt bar (.bar material, 11pt secondary text); StatusBarItem(icon:, text) = one cell with a trailing vertical divider. Add more cells inside the StatusBarView closure in MainWindowView.
    │   └── IconActionButtonStyle.swift  Reusable ButtonStyle for small icon buttons. Uses configuration.isPressed only (no @State): on press, shrinks (scaleEffect 0.80) and flashes a tinted rounded background (tint param, default .primary). Gives visible click feedback. Applied to MacroRowView play/stop/edit/delete and MacroStepRowView per-step controls.
    ├── MacroEditor/
    │   ├── CreateMacroView.swift      MACRO CREATION/EDIT SCREEN. Shown as a .sheet from HomeView (780x600). Compact/minimalist form over a MacroDraft: compact header (icon + title + subtitle) + untitled Identificação card (name with duplicate validation + description) + single "Execução" card combining Intervalo (typed ms field + presets) and Repetições (typed field, stepper, presets) as two side-by-side columns separated by a vertical divider, with one shared caption ("⌘Esc interrompe") + Ações card (titled, "Adicionar" Menu, ordered step rows, empty state). Footer has step count, Executar macro/Parar, Cancelar, Salvar/Salvar Alterações. Rows reorder by drag handle with drop indicator; no step selection. Header adapts for edit mode. Prevents saving with duplicate names. Keyboard shortcuts: ⌘↑/⌘↓ move selected step.
    │   ├── MacroStepRowView.swift     One editable step row: colored kind icon, numbered title, specialized inline editor per kind (capture button + modifier toggles + key Picker for shortcuts, ScreenCoordinatePicker for click/drag, window-title Picker (WindowCatalog) for the "Selecionar janela" step; ms field for delay; text mode segmented control for typeText; move-mouse + record-scroll for scroll, Picker+Slider for scroll, TextField for text/URL, Slider for delay), selection highlight, a drag handle (left, draggable/dropDestination reorder), a play button to test the single step via ActionTester, and move-up/move-down/delete controls.
    │   ├── ScreenCoordinatePicker.swift  AppKit overlay (NSPanel) for capturing screen coordinates. Single-click mode for .click steps; fluid click-drag-release mode for .dragAndDrop steps. Shows a full-screen crosshair (vertical + horizontal line following the mouse, with live x/y label), instruction HUD, markers (A/B) and dashed drag line.
    │   ├── ScrollCapturePicker.swift  Records a real scroll: listenOnly CGEvent tap + HUD; finishes after 1s idle, returns mouse position, direction, amount.
    │   ├── AutoFocusTextField.swift   NSTextField bridge that takes focus when StepFocusRequest.pendingStepID matches (set when a typeText step is added).
    │   ├── ShortcutCapturePicker.swift  Floating HUD that captures ANY key combo (active CGEvent tap swallows the keys so ⌘Q/⌘W etc. don't hit the app; falls back to NSEvent local monitor without permission). Shows live modifiers. Opened automatically when a .keyShortcut step is added, or via Capturar/Recapturar button.
    ├── TestLab/
    │   └── TestLabView.swift      TEST SCREEN (sidebar "Testes", AppSection.testLab). Cards: Ações (add any step kind, edit with MacroStepRowView, per-step "Testar" + "Testar todas"), Opções (countdown 0–10s, interval, hide app, cancel), Resultados (success/fail log with duration).
    ├── Inspector/
    │   ├── InspectorPanelController.swift  AppKit NSPanel controller for the floating inspector. Shows/hides the panel, positions it top-right. Owns InspectorState lifecycle (start/stop on show/close).
    │   └── InspectorPanelView.swift   SwiftUI content for the inspector panel: live X/Y coordinates (monospaced), active/inactive indicator, copy-to-clipboard button.
    ├── Home/
    │   ├── HomeView.swift             HOME SCREEN. Takes AppState. Composes ActionsRow (top) + execution banner (when running) + MacroListView (bottom). Hosts CreateMacroView .sheet. Wires all three action cards: Nova Macro, Inspetor, Gravar Ações.
    │   ├── StatsCardView.swift        ActionCardView component: clickable card with icon, title, color, optional isActive state (pulse animation + tinted background). Used by ActionsRow.
    │   ├── StatsCardsRow.swift        ActionsRow: horizontal row of ActionCardView cards. All three wired: Nova Macro (opens create sheet), Inspetor (toggles floating panel), Gravar Ações (starts/stops recording). Shows active states.
    │   ├── MacroListView.swift        Takes MacroStore + MacroExecutor. Two sections: "Usados Recentemente" (top 3) and "Todas as Macros". Each row has play/stop/edit/delete buttons. Animated insert/remove transitions. Context menu with execute + edit + delete.
    │   └── MacroRowView.swift         Single macro row: icon, name, details, play/stop/edit/delete inline buttons, createdAtLabel, executionCount + lastUsedLabel, step count badge. Context menu: Executar, Editar, Apagar. Smooth transitions between states.
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
| Interactive action editors per step kind | Each MacroStepKind uses a specialized editor: screen overlay for click/drag coordinates, NSView-based shortcut recorder for keyboard shortcuts, Accessibility-API window-title picker (WindowCatalog) for window selection, Picker+Slider for scroll. No generic text fields for structured data |
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

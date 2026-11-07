# MacroTic — File & Directory Map

> Reference for AI agents. Every file and directory in this project with its exact purpose, contents, and relationships.

## Project Overview

- **What**: Native macOS app — macro automation tool. Classic window with sidebar navigation, Home screen (macro list + creation), and Settings screen.
- **Stack**: Swift 6.4, SwiftUI + AppKit hybrid, Swift Package Manager (no Xcode project)
- **Target**: macOS 26+
- **Language mode**: Swift 5 (SwiftUIMacros plugin is NOT available — `@State`, `@Binding`, `@Environment` cannot be used)
- **Observation**: Uses `@Observable` (ObservationMacros IS available). Bindings are created manually via `Binding(get:set:)`.
- **Dock icon**: `.regular` activation policy. Closing the window quits the app (`applicationShouldTerminateAfterLastWindowClosed`) — EXCEPT while a macro is running: that delegate returns false when `windowController.isPresentingRun` is true, because during a run the app's windows are intentionally ordered out (only the HUD panel stays) and that must not count as "last window closed" and quit the app mid-run (that bug made the whole app, HUD included, vanish on execute).

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
                                Needs repo secrets: SPARKLE_PRIVATE_KEY, SPARKLE_PUBLIC_KEY (see Scripts/generate_sparkle_keys.sh), and
                                CODESIGN_P12_BASE64, CODESIGN_P12_PASSWORD, CODESIGN_IDENTITY for the stable self-signed code signing
                                identity (imports the cert into a throwaway keychain, deletes it at the end regardless of job outcome;
                                does NOT call security add-trusted-cert — that modifies Trust Settings, which can require GUI
                                authorization that hangs forever on a headless runner, and codesign --sign "<identity>" doesn't need it).

Packaging/
├── Info.plist                 Template Info.plist for the packaged app. Placeholders __VERSION__, __OWNER__, __REPO__,
│                                __SPARKLE_PUBLIC_KEY__ are substituted by Scripts/package_app.sh. CFBundleIconFile/
│                                CFBundleIconName point at AppIcon (AppIcon.icns, copied in by package_app.sh).
│                                SUFeedURL points to https://github.com/<owner>/<repo>/releases/latest/download/appcast.xml
│                                (GitHub's stable "latest" redirect — always resolves to the one release kept published).
│                                SUEnableAutomaticChecks + SUAutomaticallyUpdate are both true: updates download and
│                                install automatically without prompting.
├── AppIcon.icns                App icon (blue/purple gradient rounded square, white ⌘ glyph), built via iconutil from
│                                AppIcon-1024.png at the standard 16–512pt (@1x/@2x) sizes. Copied into
│                                Contents/Resources/AppIcon.icns by package_app.sh.
└── AppIcon-1024.png            1024×1024 master render of the icon artwork — regenerate the .iconset/.icns from this if
                                 the design changes (rendered via AppKit: NSGradient rounded-rect + SF Symbol "command", not
                                 checked into any build graph).

Scripts/
├── package_app.sh              Builds build/MacroTic.app from .build/release, embeds Sparkle.framework into
│                                Contents/Frameworks, copies Packaging/AppIcon.icns into Contents/Resources, fills in
│                                Packaging/Info.plist, codesigns (deep, including Sparkle's nested XPC services/Autoupdate/
│                                Updater.app) using $CODESIGN_IDENTITY — the stable self-signed "MacroTic Code Signing"
│                                identity in CI/release builds, falling back to ad-hoc ("-") for local dev builds where it
│                                isn't set — then zips to dist/MacroTic-<version>.zip.
├── build_appcast.sh             Downloads the Sparkle CLI tools matching Package.resolved's pinned version, runs
│                                generate_appcast against dist/ to sign the zip (EdDSA) and emit dist/appcast.xml.
│                                Reads the private key from SPARKLE_PRIVATE_KEY (never written to disk outside a temp file).
└── generate_sparkle_keys.sh     Run locally (not in CI) once to generate the Sparkle EdDSA key pair via the official
                                 generate_keys tool. Private key goes to the login Keychain / GitHub secret
                                 SPARKLE_PRIVATE_KEY; public key goes into Packaging/Info.plist and GitHub secret
                                 SPARKLE_PUBLIC_KEY.
```

Release builds are signed with a stable self-signed code signing identity ("MacroTic Code Signing", no Apple Developer ID /
Team ID) instead of ad-hoc. This keeps the app's designated requirement identical across every release, so macOS TCC grants
(Accessibility, etc.) survive an auto-update instead of resetting on every new signature — which ad-hoc signing (ever-changing
per-build hash) caused. It does NOT satisfy Gatekeeper/notarization: first launch after install/update still shows a Gatekeeper
warning until a paid Apple Developer ID + notarization is added. The same identity is imported into the login keychain on this
machine for local release packaging; CI imports it into a throwaway keychain per run from the CODESIGN_P12_BASE64 secret.

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
│   ├── MacroTicApp.swift          ENTRY POINT. @main enum MacroTicApp; AppDelegate creates MainWindowController,
│   │                              quits when the last window closes (unless a run is being presented — see above), and calls AXIsProcessTrustedWithOptions (prompt: true)
│   │                              on launch so macOS registers the app under Accessibility and prompts the user if needed
│   │                              (required for CGEvent posting in MacroExecutor to actually have any effect).
│   ├── MainWindowController.swift Creates the classic NSWindow (titled, closable, miniaturizable, resizable,
│   │                              750x510, min 750x510, centered, zoom/maximize disabled) hosting MainWindowView. Title is
│   │                              "MacroTic — v<CFBundleShortVersionString>" (titleWithVersion) so the running build's
│   │                              version is always visible. Owns AppState.
│   │                              Attaches a native NSToolbar (unified style, NSToolbarDelegate on self) with a single
│   │                              flexible-space + gearshape item that toggles state.selectedSection between .home/.settings
│   │                              (no sidebar). On init it calls state.updater.checkForUpdatesAtStartup() so the little update panel
│   │                              (UpdateProgressWindow) appears at launch. Observes state.isCreatingMacro via withObservationTracking and swaps to a separate 680x540
│   │                              editor window (titled "Nova Macro"/"Editar Macro", resizable with min size 620×480, no miniaturize) that hosts
│   │                              CreateMacroView; while the editor is open the main window is orderOut'd. windowShouldClose on
│   │                              the editor is intercepted and routed to state.closeEditor() (clears editingMacroID +
│   │                              isCreatingMacro, returns false so AppDelegate's "terminate on last window closed" never fires).
│   │                              Also observes state.macroExecutor.isRunning (second withObservationTracking loop): while a macro
│   │                              runs it shows a floating, non-activating borderless NSPanel HUD in the top-right corner (hosts
│   │                              ExecutionHUDView: live step/repetition progress + Parar button + ⌘Esc hint) and THEN orderOut's
│   │                              every visible non-panel window (the app "disappears"), only hiding them once the HUD is confirmed
│   │                              on screen. The panel sets hidesOnDeactivate=false (NSPanel defaults to true — without this the HUD
│   │                              vanishes the instant the macro gives focus to another app, which looked like a crash) and uses
│   │                              level .statusBar + canJoinAllSpaces/fullScreenAuxiliary/stationary so it stays visible over the
│   │                              app being automated, even in fullscreen. The target screen is captured before hiding (NSScreen.main
│   │                              goes nil once the app has no key window). On finish/stop it orders the HUD out and restores the
│   │                              windows it hid. ⌘Esc still cancels because the cancel tap lives in MacroExecutor, independent of
│   │                              window visibility.
│   ├── UpdaterController.swift    SPARKLE WRAPPER. @Observable class around a bare SPUUpdater (NOT SPUStandardUpdaterController)
│   │                              wired to the custom SilentUpdateUserDriver, so the whole update flow drives our own little
│   │                              progress window instead of Sparkle's standard dialogs. start() is called on init (packaged .app
│   │                              only). Exposes canCheckForUpdates + lastCheckDate (KVO-observed), isAvailable, and read-only
│   │                              automaticallyChecksForUpdates/automaticallyDownloadsUpdates/checkIntervalHours/feedURLString.
│   │                              checkForUpdates() = user-initiated (Settings button); checkForUpdatesAtStartup() = the launch
│   │                              check that shows the panel: it flags the driver (beginStartupCheck) then checks. Called once from
│   │                              MainWindowController.init. Behavior/feed come from Contents/Info.plist (see Packaging/Info.plist).
│   │                              No-op outside a packaged .app.
│   ├── SilentUpdateUserDriver.swift  Custom SPUUserDriver that replaces Sparkle's standard UI. Auto-approves permission, auto-installs
│   │                              any found update (reply .install), never shows release notes. On the STARTUP check (flagged via
│   │                              beginStartupCheck) it shows UpdateProgressWindow — "Verificando atualizações…" → if up to date, holds
│   │                              the panel a minimum ~2s then shows "Você já está na versão mais recente" for ~1.2s and fades out; if an
│   │                              update is found, swaps to "Baixando…/Instalando…/Reiniciando…" with real download+extraction progress
│   │                              (download mapped to 0–0.9, extraction 0.9–1.0) and a 5s minimum visible duration before relaunch. A
│   │                              user-initiated check with no update shows a plain NSAlert instead of the panel; errors on startup just
│   │                              dismiss the panel silently, errors on a user check show an alert.
│   └── UpdateProgressWindow.swift  The "janelinha": a borderless, floating, non-activating NSPanel (320×148, HUD-material rounded
│                                  NSVisualEffectView) centered on screen with the app icon, a status label, and an NSProgressIndicator
│                                  bar. Fade-in on show(), fade-out on close(). setStatus/setIndeterminate/setProgress drive it; owned
│                                  and sequenced entirely by SilentUpdateUserDriver. Ported from the FastReport app's update UI.
├── Models/
│   ├── AppSection.swift           Section identifiers (enum: home, settings — id, title, icon), used by state.selectedSection.
│   ├── AppState.swift             @Observable: selectedSection, updater, isCreatingMacro flag + macroDraft + editingMacroID, macroStore, macroExecutor, actionRecorder. Methods: beginCreatingMacro(), beginEditingMacro(), saveMacro() (persists create-vs-edit but does NOT close the editor — on first save of a new macro it adopts the saved id as editingMacroID so repeated "Salvar Alterações" updates instead of duplicating; on edit it preserves the original's isFavorite since that is set from Home, not the editor), closeEditor() (clears editingMacroID + isCreatingMacro — used by Cancelar/Fechar and the window close button), deleteMacro() (animated), playMacro() (ignores a second play while already running and only marks the macro as used when Accessibility is granted, so counts/"recently used" don't inflate on a blocked run), stopMacro(), startRecording(), stopRecording(), toggleEditorRecording() (in-editor record: starts recorder, on stop appends captured steps to the current draft).
│   ├── Macro.swift                Domain model (struct, Codable): id, name, details, iconName, steps:[MacroStep], intervalBetweenSteps (default 0.5s), repeatCount (default 1, executor repeats the whole sequence), createdAt, lastUsedAt, executionCount, isFavorite, isLocked (both decodeIfPresent default false). isLocked = the editor's safety lock, persisted so a macro saved locked reopens locked. Provides createdAtLabel (dd/MM/yyyy HH:mm) and lastUsedLabel computed properties. Backwards-compatible Codable (decodeIfPresent for intervalBetweenSteps).
│   ├── MacroExecutor.swift        @Observable orchestrator. Delegates each step to the matching MacroAction from Actions/. Tracks runningMacroID (the id of the macro currently executing, nil when idle/finished/error/stopped) so the macro list highlights only the running row, not every row. Before running, checks AXIsProcessTrusted() and, if not granted, sets state to .error with an instructional message, re-prompts via AXIsProcessTrustedWithOptions, and opens System Settings → Accessibility (CGEvent posting is silently a no-op without this permission). Runs on Task.detached (background), updates state on MainActor. Repeats the full captured step sequence macro.repeatCount times, waiting intervalBetweenSteps between every step (including across the rep boundary). It does NOT refocus MacroTic between repetitions — the app stays hidden for the whole run (MainWindowController hides the windows + shows the HUD) and only comes back at the very end. execute(_:startAt:) can start a run partway through the sequence (used by the editor's "Executar a partir daqui"): startAt>0 runs a single pass from that step to the end, startAt==0 honours repeatCount. Tracks state (idle/running/paused/finished/error). Restores the cursor to its original position when the macro ends/stops. On finish/error/stop calls activateApp() to bring MacroTic's window back to the front. stop() cancels currentTask; actions cooperatively check Task.isCancelled inside their own per-frame loops (not just between steps) so ⌘Esc actually interrupts mid-action instead of waiting for a long click/drag/scroll/type to finish. The ⌘Esc cancel shortcut is a session-level CGEvent tap (.cgSessionEventTap, headInsert, defaultTap — swallows the matched ⌘Esc) installed while running, NOT an NSEvent global/local monitor: NSEvent global keyDown monitoring needs the separate Input Monitoring permission (the app only has Accessibility) and during a run MacroTic is backgrounded so the local monitor never fires — the CGEvent tap is gated by Accessibility (same as ActionRecorder) and fires regardless of which app is frontmost. Re-enables itself on tapDisabledByTimeout/UserInput. Methods: execute(), pause(), resume(), stop().
│   ├── Actions/
│   │   ├── MacroAction.swift          Protocol: `execute(step:) -> Bool`. All action types conform to this.
│   │   ├── KeyShortcutAction.swift    Parses step.value via ShortcutKeyMap, presses modifier keys (flagsChanged), posts key down/up, releases modifiers. Not cancellation-aware (sequence is short and must fully release modifiers to avoid stuck keys).
│   │   ├── TypeTextAction.swift       step.textMode: .typing = char-by-char CGEvent unicode injection (checks Task.isCancelled before each character); .paste = sets pasteboard, sends ⌘V, restores previous clipboard.
│   │   ├── ClickAction.swift          Moves cursor to step.clickX/clickY (checks Task.isCancelled each move frame, before mouseDown is posted), posts mouseDown/mouseUp with timing gaps. Zeroes the event source's localEventsSuppressionInterval and, after the move, warps the cursor to the exact target + re-associates + settles 60ms, then posts an explicit mouseMoved AT the target (so the window under the cursor registers hover — a click on a not-yet-focused window is otherwise sometimes swallowed as a mere window-raise and never lands) before clicking. This also fixes the very first click of a run (cursor traveling in from far away) routing to the old cursor location.
│   │   ├── DelayAction.swift          Sleeps for step.delay seconds (edited in milliseconds in the UI).
│   │   ├── FocusWindowAction.swift    Brings the window named by step.value (a window title) to the front, reliably. Resolves the title via WindowCatalog to its owner PID, then: (1) activates the owning app (NSRunningApplication + AX kAXFrontmostAttribute=true — the AX frontmost is what actually wins when another app is currently active), (2) finds the matching window by kAXTitle (falls back to the app's first window) and raises it (kAXMain=true + kAXRaiseAction + sets the app's kAXFocusedWindow), (3) re-asserts frontmost+raise after a short settle so it doesn't lose the focus race against the previously-frontmost app letting go.
│   │   ├── DragAndDropAction.swift    Smoothstep-eased drag from start to end coordinates (30 interpolation steps). Checks Task.isCancelled each frame; once mouseDown has been posted, a cancelled drag still always posts the final mouseUp (so it never leaves a stuck virtual drag), returning false to report the stop.
│   │   └── ScrollAction.swift         Optionally moves the mouse to step.scrollX/Y first (scrollMovesMouse): zeroes the event source's localEventsSuppressionInterval and waits 300ms so the warp settles before scrolling (otherwise early events route to the old cursor location). Then scrolls deterministically via a single scroll(unit:perEvent:delayMs:) loop (checks Task.isCancelled each frame) that posts small uniform deltas until the exact total is reached — NO scroll-phase/momentum emulation (phases caused inconsistent inertia across apps). .lines = 1 line per event every 25ms; .pixels = 10px per event every 8ms with scrollWheelEventIsContinuous set.
│   ├── ActionRecorder.swift       @Observable action recorder. Uses CGEvent tap (listenOnly) to capture clicks, keystrokes, scroll events into MacroStep array. "Smart" capture: does NOT record pauses (no auto-delay steps), ignores key auto-repeat (keyboardEventAutorepeat) so holding a key isn't duplicated, coalesces plain typing (including Shift for capitals/symbols, decoded via keyboardGetUnicodeString) into a single typeText step, routes Backspace to edit that typed-text buffer instead of adding a step, and only emits a keyShortcut step for real combos (⌘/⌃/⌥) or non-typing special keys (Return/Tab/Esc/arrows/F-keys/nav — Space is typed, not special). Consecutive same-direction scrolls merge. Ignores left-clicks inside MacroTic's own visible windows (single-display coordinate flip) so the toggle click isn't captured. Methods: startRecording(), stopRecording(), makeDraft().
│   ├── ShortcutKeyMap.swift       Single source of truth for shortcut strings (e.g. "⌘⇧C"): key code ↔ name tables, modifier symbols, parse() (also accepts legacy "⌘+c" / "cmd+Return"). Used by KeyShortcutAction and ShortcutCapturePicker.
│   ├── WindowCatalog.swift        Lists currently open windows via the Accessibility API (AXWindows of every regular running app, excluding MacroTic), each identified by its window title. titles() → sorted unique titles for the "Selecionar janela" dropdown; window(forTitle:) resolves a title back to its owner PID for FocusWindowAction; frame(forTitle:) returns that window's AX screen rect (CG top-left) for DebugPreviewOverlay's window highlight. Queried live (no cache / refresh).
│   ├── MacroStore.swift           @Observable JSON persistence layer. Saves/loads macros to ~/Library/Application Support/MacroTic/macros.json. Methods: save, delete, markUsed, toggleFavorite(id), exportJSON, importJSON, exportURL. Provides `sorted` (all macros, favorites first, each group keeping its newest-first order) — the "Usados Recentemente" section was removed in favour of this favorites model.
│   ├── MacroIO.swift              Single-macro import/export via native NSSavePanel/NSOpenPanel. export(_ macro:) writes pretty-printed ISO-8601 JSON to a user-chosen .json file; importMacro(completion:) reads a .json and decodes either a single Macro or the first of a [Macro] array, calling back on the main thread. Used by CreateMacroView's "Importar/Exportar macro" menu.
│   ├── MacroStep.swift            One step in a macro (struct, custom backwards-compatible decode): id, kind, value, delay, textMode (TextInputMode), scrollMovesMouse + scrollX/Y + scrollUnit (lines/pixels) + scrollStepDelayMs, clickX/clickY (for .click), dragStartX/Y + dragEndX/Y (for .dragAndDrop), scrollDirection + scrollAmount (for .scroll). Also defines ScrollDirection enum. Computed supportsDebugPreview flags steps that DebugPreviewOverlay can visualize (click/drag with coords, scroll, launchApp with a title).
│   ├── MacroStepKind.swift        Step types (enum: keyShortcut, typeText, click, delay, launchApp, dragAndDrop, scroll; openURL was removed — legacy steps are dropped on load via Macro's lossy decode). Each provides title, icon, tint color, placeholder, and boolean flags: usesDelay, usesCoordinates, usesDragCoordinates, usesScroll, usesShortcutRecorder, usesWindowPicker, usesTextField.
│   └── MacroDraft.swift           @Observable editor/form state for building a macro: name, details, iconName, steps, intervalBetweenSteps, repeatCount, dropTargetID, debugMode (hover previews), showQuickBar (icon action toolbar visible), isLocked (safety lock, persisted via Macro.isLocked), selectedStepIDs:Set<UUID> (multi-selection of rows for ⌘↑/⌘↓ reorder and ⌘⌫ delete) + add/remove/moveUp/moveDown/move(before:) and selection ops: toggleSelection, allSelected, selectAll, clearSelection, removeSelected, and block-aware moveSelectedUp/moveSelectedDown (shift each contiguous selected block by one, preserving multi-row selections). isValid, loadFrom(Macro), makeMacro(), makeMacro(preservingID:). remove() also drops the id from selectedStepIDs. duplicate() copies the full MacroStep via MacroStep.copyWithNewID(). Retained on AppState so edits survive view re-renders.
└── Views/
    ├── MainWindowView.swift       Wraps everything in a GeometryReader: content above + StatusBarView below showing the current window size ("W × H px", includes safe-area insets so it equals the window content size). No sidebar — content switches directly on state.selectedSection: SettingsView for .settings, HomeView(state:) otherwise. The toolbar gear button that drives selectedSection lives in MainWindowController (native NSToolbar).
    ├── ExecutionHUDView.swift     Small floating progress HUD shown (in a top-right non-activating NSPanel created by MainWindowController) while a macro runs and the app's windows are hidden: spinner + "Executando macro" + live "Rep x/y · passo n/N" status (reads MacroExecutor.state/currentRepetition/totalRepetitions) + red "Parar" button (→ state.stopMacro()) + ⌘Esc hint. Fixed 320pt width, material capsule card.
    ├── Components/
    │   ├── StatusBarView.swift  Classic bottom status bar. StatusBarView { content } = top divider + 22pt bar (.bar material, 11pt secondary text); StatusBarItem(icon:, text) = one cell with a trailing vertical divider. Add more cells inside the StatusBarView closure in MainWindowView.
    │   └── IconActionButtonStyle.swift  Reusable ButtonStyle for small icon buttons. Uses configuration.isPressed only (no @State): on press, shrinks (scaleEffect 0.80) and flashes a tinted rounded background (tint param, default .primary). Gives visible click feedback. Applied to MacroRowView play/stop/edit/delete.
    ├── MacroEditor/
    │   ├── CreateMacroView.swift      MACRO CREATION/EDIT SCREEN. Shown in a dedicated 680x540 editor window. Minimalist layout, no card chrome: compact identity header (icon + inline name TextField + inline description under it, duplicate-name warning icon) + single-line execution bar (Intervalo ms field + Repetir count field+stepper + ⌘Esc hint) over a subtle quaternary background + full-height "Ações" section (header with count chip + "Gravar ação" / "Parar gravação" button (via state.toggleEditorRecording — captured steps are appended to the draft on stop) + "Adicionar ação" Menu + "Importar/Exportar macro" ellipsis Menu (MacroIO), scrolling single-line step rows). The Ações header has icon toggles (headerToggle): a safety lock (orange, lock.fill/lock.open) toggling draft.isLocked, one that shows/hides the quickBar, and one toggling draft.debugMode (turning it off hides the DebugPreviewOverlay). editingLocked = draft.isLocked || executor.isRunning: when true, every editing control is disabled (identity/execution fields, quickBar, recordButton, addMenu, import, each row's editor/actions/drag/reorder, the ⌘↑/⌘↓/⌘⌫ shortcuts and the selection Excluir) via .disabled, and a lockedBanner shows; Executar/Salvar/Fechar/selection-run stay enabled. So a run auto-locks before anything and reverts to the user's lock state at the end (a macro saved locked stays locked until manually unlocked). The lock toggle itself is disabled while running. quickBar is the hideable icon-only toolbar — one tinted icon button per MacroStepKind that adds that action with a tap (draft.showQuickBar). debugMode passes down to each MacroStepRowView, which on hover calls DebugPreviewOverlay.shared.show(for:)/hide() for steps that supportDebugPreview and shows a small teal eye badge on previewable rows. The Ações list is table-like: a tableHeader row (select-all checkbox + #/Ação/Configuração column labels aligned via StepRowLayout) over the scrolling rows, with a contextual selectionBar (shown when ≥1 row is selected: count + ⌘↑/⌘↓/⌘⌫ hint + Executar (runs ONLY the selected steps in order, via onRunSelected → a one-pass temp Macro) + Excluir + Limpar). Footer has FOUR buttons: Executar/Parar (left, ⌘R) then Cancelar (Esc, discard+close via onCancel→closeEditor), Salvar Alterações (⌘S — persists but does NOT close the window), Fechar (⌘W, borderedProminent — closes via onClose→closeEditor). A zero-size opacity-0 background (selectionShortcuts) holds Buttons bound to ⌘↑/⌘↓ (draft.moveSelectedUp/Down) and ⌘⌫ (draft.removeSelected), disabled when selectedStepIDs is empty. onRunFrom(index) runs the draft from a chosen step. The view uses a flexible min/ideal/max frame (min 620×480) so the editor window is resizable. Prevents saving with duplicate names.
    │   ├── MacroStepRowView.swift     One table-aligned single-line step row. Columns use the shared StepRowLayout widths (selector/handle/index/icon/title) so every row lines up with CreateMacroView's tableHeader: a selection checkbox (onSelect → toggles membership in draft.selectedStepIDs, selected rows get a subtle accent background), drag handle, position number, colored kind icon, fixed-width kind title, the specialized inline editor (shortcut chip + Capturar; click coords + Capturar; drag coords A→B + Capturar; scroll direction/amount/unit pickers + Gravar + move-mouse toggle + optional position capture; AutoFocusTextField + mode Menu for typeText; ms field for delay; window-title Picker for launchApp) filling remaining width, then visible action icons: Duplicar + Remover (trash), plus an overflow Menu (ellipsis) with "Executar a partir daqui" (onRunFrom) and Mover para cima/baixo. Drop-target capsule indicator. When debugMode is on, previewable rows (step.supportsDebugPreview) show a teal eye badge and drive DebugPreviewOverlay.show/hide on hover.
    │   ├── DebugPreviewOverlay.swift   Debug-mode visualizer. DebugPreviewOverlay.shared manages a full-screen, click-through (ignoresMouseEvents), transparent borderless NSPanel at .screenSaver level (hidesOnDeactivate=false, all-spaces/fullScreen) hosting DebugOverlayView. show(for: MacroStep) configures a visualization and orders the panel front; hide() clears it. DebugOverlayView draws (Timer-driven ~30fps phase loop, NSBezierPath) per step kind: .click = pulsing red rings + center dot at the click point; .dragAndDrop = marching-ants dashed line with A (green)/B (red) markers and a dot travelling A→B; .scroll = teal ring with animated directional arrows (uses scrollX/Y when scrollMovesMouse, else screen center); .launchApp = pulsing green rounded-rect around the target window's AX frame (WindowCatalog.frame(forTitle:)). CG(top-left)→Cocoa(bottom-left) conversion via NSScreen.main height, consistent with the pickers. keyShortcut/typeText/delay have no preview. Hidden when a run starts (MainWindowController.beginRunPresentation) and on editor close.
    │   ├── ScreenCoordinatePicker.swift  AppKit overlay (NSPanel) for capturing screen coordinates. Single-click mode for .click steps; fluid click-drag-release mode for .dragAndDrop steps. Shows a full-screen crosshair (vertical + horizontal line following the mouse, with live x/y label), instruction HUD, markers (A/B) and dashed drag line.
    │   ├── ScrollCapturePicker.swift  Records a real scroll: listenOnly CGEvent tap + HUD; finishes after 1s idle, returns mouse position, direction, amount.
    │   ├── AutoFocusTextField.swift   NSTextField bridge that takes focus when StepFocusRequest.pendingStepID matches (set when a typeText step is added).
    │   ├── ShortcutCapturePicker.swift  Floating HUD that captures ANY key combo (active CGEvent tap swallows the keys so ⌘Q/⌘W etc. don't hit the app; falls back to NSEvent local monitor without permission). Shows live modifiers. Opened automatically when a .keyShortcut step is added, or via Capturar/Recapturar button.
    ├── Home/
    │   ├── HomeView.swift             HOME SCREEN. Takes AppState. Composes ActionsRow (top) + execution banner (when running) + MacroListView (bottom). The macro editor is presented in a separate window by MainWindowController (not a sheet here). Wires both action cards: Nova Macro, Gravar Ações.
    │   ├── StatsCardView.swift        ActionCardView component: clickable card with icon, title, color, optional isActive state (pulse animation + tinted background). Used by ActionsRow.
    │   ├── StatsCardsRow.swift        ActionsRow: horizontal row of ActionCardView cards: Nova Macro (opens the editor) and Gravar Ações (starts/stops recording — stop opens the editor with a new draft from the recording). Shows active state while recording.
    │   ├── MacroListView.swift        Takes MacroStore + MacroExecutor. A single "Macros" section listing store.sorted (favorites first), no duplicates and no separate recents section. Each row has a favorite star + play/stop/edit/delete buttons. onToggleFavorite wired to store.toggleFavorite. Animated insert/remove/reorder transitions.
    │   └── MacroRowView.swift         Single macro row: leading favorite star toggle (onToggleFavorite), icon, name, details, executionCount + lastUsedLabel, step count badge, play/stop/edit/delete inline buttons. Context menu: Executar, Editar, Favoritar/Remover dos favoritos, Apagar.
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

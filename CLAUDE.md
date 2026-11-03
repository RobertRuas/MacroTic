# CLAUDE.md — Agent Rules for MacroTic

## Navigation Rule (mandatory, every task)

Before writing code, making changes, or taking any decision:

1. **Read `AI_PROJECT_MAP.md` first** — it is the single source of truth for what exists, where it lives, and what each file does.
2. **Go directly to the relevant file(s)** — use the map to identify the exact file you need. Do not scan, list, or read files that are unrelated to the task.
   - Design/visual change → read the specific view file (e.g. `ActivationTab.swift`, `TitleBar.swift`)
   - State/logic change → read `AppState.swift` or `PanelController.swift`
   - New screen → read the map's Screens section for the pattern, then create following the same structure
   - Settings feature → go to `Screens/Settings/` directly
3. **Never read all files.** Only read what you will change or what you need to understand a dependency.

## After structural changes

When you create, move, rename, or delete any file or directory, update `AI_PROJECT_MAP.md` to reflect the change before finishing the task.

## Creating a New Release

When the user asks to "release", "tag", "publish", or "create release" (with or without a version number):

1. **Commit all pending changes** to `main`:
   ```bash
   git add .
   git commit -m "message"
   git push origin main
   ```

2. **Determine version number**:
   - If user specifies a version (e.g. "v0.2.0", "0.2.0"), use it as-is
   - If no version given, ask the user: "What version? (e.g., 0.2.0, 1.0.0)"
   - Format must be semver: `v*.*.* `(e.g., v0.2.0, v1.0.0, v1.2.3)

3. **Create and push the tag**:
   ```bash
   git tag -a v<VERSION> -m "Release version <VERSION>"
   git push origin v<VERSION>
   ```

4. **Monitor the workflow**:
   - GitHub Actions Release workflow triggers automatically on tag push
   - Wait for the workflow to complete
   - Verify release was created: `gh release view v<VERSION>`
   - Verify assets exist: appcast.xml + MacroTic-<VERSION>.zip

5. **Report success** with release link:
   ```
   ✅ Released v<VERSION>
   https://github.com/RobertRuas/MacroTic/releases/tag/v<VERSION>
   ```

**See RELEASES.md** for full documentation on the release process, auto-update system, and troubleshooting.

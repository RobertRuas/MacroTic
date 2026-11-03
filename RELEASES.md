# Release & Auto-Update Guide

This document explains how to release new versions of MacroTic and how the automatic update system works.

## Current Release Status ✅

- **Latest Release**: v0.1.0
- **Status**: Fully functional with automatic updates enabled
- **Auto-Update Feed**: `https://github.com/RobertRuas/MacroTic/releases/latest/download/appcast.xml`
- **Sparkle EdDSA Key**: Configured and stored securely in GitHub secrets

## How to Release a New Version

### 1. Make Your Changes
Commit all changes to the `main` branch:
```bash
git add .
git commit -m "feat: description of your changes"
git push origin main
```

### 2. Create a Version Tag
Create an annotated git tag with the version number (following semantic versioning):
```bash
git tag -a v0.2.0 -m "Release version 0.2.0"
git push origin v0.2.0
```

**Tag Format**: Must match `v*.*.*` (e.g., `v0.2.0`, `v1.0.0`, `v1.2.3`)

### 3. GitHub Actions Workflow Runs Automatically
When you push a tag matching `v*.*.*`, the Release workflow automatically:

1. **Extracts version** from the git tag
2. **Resolves Swift dependencies** with SPM
3. **Builds release binary** in release mode
4. **Packages the app** into MacroTic.app
5. **Embeds Sparkle.framework** into Contents/Frameworks
6. **Signs the app** with ad-hoc codesigning
7. **Zips the app** to dist/MacroTic-X.X.X.zip
8. **Builds appcast.xml** with EdDSA signature (for Sparkle update verification)
9. **Creates GitHub Release** with both the zip and appcast.xml
10. **Cleans up old releases** — only the latest release is kept published

## Automatic Updates

### How It Works

1. **Users run the app** after downloading from the latest release
2. **App checks for updates** automatically once per day (configured in `Packaging/Info.plist`)
3. **Sparkle framework** queries the appcast.xml feed URL from GitHub
4. **If a new version is available**, Sparkle downloads and installs it automatically
5. **App relaunches** with the new version

### Feed URL

The feed URL in `Packaging/Info.plist` is:
```
https://github.com/RobertRuas/MacroTic/releases/latest/download/appcast.xml
```

This URL uses GitHub's stable "latest" redirect, which always points to the most recent release. When the workflow creates a new release, it automatically deletes all older releases, so "latest" always resolves to the current version.

### Security

- **EdDSA Signatures**: All app updates are digitally signed with an EdDSA private key
- **Public Key Verification**: The public key is embedded in `Packaging/Info.plist`
- **Private Key**: Stored securely in GitHub repository secret `SPARKLE_PRIVATE_KEY`
- **No Installation Prompts**: Updates download and install automatically without user interaction

## Gatekeeper Warning (First Launch)

⚠️ **Note**: Since ad-hoc signing is used (not a Developer ID), users will see a Gatekeeper warning on first launch after downloading or updating. To remove this, you'll need to:

1. Obtain an Apple Developer ID certificate
2. Sign the app with the certificate during packaging
3. Notarize the app with Apple

See the [Apple Developer documentation](https://developer.apple.com/help/app-sandbox/notarize-your-app/) for details.

## Troubleshooting

### If the Release Workflow Fails

Check the GitHub Actions logs:
```bash
gh run list --limit 5
gh run view <run-id> --log-failed
```

Common issues:
- **Swift version mismatch**: The runner must have Swift 6.2.0 or higher
- **Dependencies**: Check that `swift package resolve` completes successfully
- **Signing failures**: Ad-hoc signing should always succeed; if it fails, check file permissions

### If Updates Don't Install

1. **Check feed URL**: Verify `SUFeedURL` in `Packaging/Info.plist` is accessible
2. **Verify signatures**: Ensure `SPARKLE_PRIVATE_KEY` and `SPARKLE_PUBLIC_KEY` secrets are correct
3. **Check appcast.xml**: Download and verify the appcast is valid XML with correct EdDSA signature
4. **Logs**: Check Console.app for Sparkle debug messages

## File Structure for Releases

```
GitHub Release (v0.2.0)
├── MacroTic-0.2.0.zip
│   └── MacroTic.app
│       ├── Contents/
│       │   ├── MacOS/
│       │   │   └── MacroTic (binary)
│       │   ├── Frameworks/
│       │   │   └── Sparkle.framework (embedded)
│       │   └── Info.plist (configured with version, feed URL, public key)
│       └── [ad-hoc codesigned]
│
└── appcast.xml (Sparkle feed, EdDSA signed)
```

## Configuration Files

### `Packaging/Info.plist`
- **Template** for the app's Info.plist
- **Placeholders** replaced during packaging: `__VERSION__`, `__OWNER__`, `__REPO__`, `__SPARKLE_PUBLIC_KEY__`
- **Sparkle settings**:
  - `SUFeedURL`: Feed URL for update checks
  - `SUPublicEDKey`: Public key for signature verification
  - `SUEnableAutomaticChecks`: true (check daily)
  - `SUAutomaticallyUpdate`: true (install without prompting)

### `.github/workflows/release.yml`
- **Trigger**: Pushes to tags matching `v*.*.*`
- **Runner**: `macos-latest` (includes Swift 6.2.0+)
- **Steps**: Compile → Package → Sign → Build appcast → Create release

### `Scripts/`
- `package_app.sh`: Builds the .app bundle and zips it
- `build_appcast.sh`: Generates Sparkle appcast.xml with EdDSA signature
- `generate_sparkle_keys.sh`: One-time key generation (already done)

## Next Steps

1. ✅ **Repository initialized** with release automation
2. ✅ **Sparkle EdDSA keys** generated and configured
3. ✅ **GitHub Actions workflow** tested and working
4. ✅ **First release** (v0.1.0) published successfully

When ready for production:
1. Obtain an Apple Developer ID certificate
2. Add code signing to the release workflow
3. Configure app notarization with Apple
4. Remove the "⚠️ Gatekeeper warning" note above

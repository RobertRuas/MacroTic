#!/bin/bash
# Run this once, locally, on your own Mac (never in CI).
# Generates the Sparkle EdDSA key pair: the private key is stored in your login
# Keychain and the public key is printed so it can be pasted into Packaging/Info.plist.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

if [ ! -f Package.resolved ]; then
    echo "Run 'swift package resolve' first so Package.resolved exists." >&2
    exit 1
fi

SPARKLE_VERSION="$(jq -r '.pins[] | select(.identity=="sparkle") | .state.version' Package.resolved)"
TOOLS_DIR=".sparkle-tools"

rm -rf "$TOOLS_DIR"
mkdir -p "$TOOLS_DIR"
curl -fL -o sparkle-tools.tar.xz \
    "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"
tar -xf sparkle-tools.tar.xz -C "$TOOLS_DIR"
rm -f sparkle-tools.tar.xz

echo ""
echo "Generating EdDSA key pair (you may be prompted for Keychain access)..."
echo ""
"$TOOLS_DIR/bin/generate_keys"

echo ""
echo "Next steps:"
echo "1. Paste the public key above into SUPublicEDKey in Packaging/Info.plist (replacing __SPARKLE_PUBLIC_KEY__)."
echo "2. Export the private key for CI:  \"$TOOLS_DIR/bin/generate_keys\" -x /tmp/sparkle_private_key.txt"
echo "   Then paste the contents of that file into a GitHub Actions secret named SPARKLE_PRIVATE_KEY,"
echo "   and delete /tmp/sparkle_private_key.txt afterwards."
echo "3. Add a second secret SPARKLE_PUBLIC_KEY with the same public key (used when packaging the app)."

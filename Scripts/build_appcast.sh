#!/bin/bash
# Signs dist/*.zip with the Sparkle EdDSA private key and generates dist/appcast.xml.
# Env vars: SPARKLE_PRIVATE_KEY (required) — the EdDSA private key string from generate_keys.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

PRIVATE_KEY="${SPARKLE_PRIVATE_KEY:?SPARKLE_PRIVATE_KEY must be set}"
SPARKLE_VERSION="$(jq -r '.pins[] | select(.identity=="sparkle") | .state.version' Package.resolved)"
TOOLS_DIR=".sparkle-tools"

if [ ! -x "$TOOLS_DIR/bin/generate_appcast" ]; then
    rm -rf "$TOOLS_DIR"
    mkdir -p "$TOOLS_DIR"
    curl -fL -o sparkle-tools.tar.xz \
        "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"
    tar -xf sparkle-tools.tar.xz -C "$TOOLS_DIR"
    rm -f sparkle-tools.tar.xz
fi

KEY_FILE="$(mktemp)"
trap 'rm -f "$KEY_FILE"' EXIT
printf '%s' "$PRIVATE_KEY" > "$KEY_FILE"

"$TOOLS_DIR/bin/generate_appcast" --ed-key-file "$KEY_FILE" dist/

echo "Generated dist/appcast.xml"

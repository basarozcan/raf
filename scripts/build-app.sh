#!/usr/bin/env bash
# Builds Raf with SwiftPM and wraps the binary in build/Raf.app.
# Usage: scripts/build-app.sh [release|debug]
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP="build/Raf.app"

swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Raf" "$APP/Contents/MacOS/Raf"
cp Support/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature so macOS will launch it locally. Use a Developer ID
# identity instead when distributing to other Macs.
codesign --force --sign - "$APP"

echo "Built $APP"
echo "Run it with: open $APP"

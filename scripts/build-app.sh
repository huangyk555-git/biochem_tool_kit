#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/module-cache
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
./scripts/swift-local.sh build -c release
BIN_DIR="$(./scripts/swift-local.sh build -c release --show-bin-path)"
APP="$PWD/outputs/biochem_tool_kit.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/BioChemPet" "$APP/Contents/MacOS/BioChemPet"
# Catalog resolves the resource bundle in the standard signed-app resource directory.
for bundle in "$BIN_DIR"/*.bundle; do
    [ -d "$bundle" ] && ditto "$bundle" "$APP/Contents/Resources/$(basename "$bundle")"
done
cp Config/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
printf 'Built: %s\n' "$APP"

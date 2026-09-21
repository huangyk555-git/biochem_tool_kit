#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/module-cache
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
./scripts/swift-local.sh build -c release
BIN_DIR="$(./scripts/swift-local.sh build -c release --show-bin-path)"
APP="$PWD/outputs/BioChem Bridge.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/BioChemPet" "$APP/Contents/MacOS/BioChemPet"
# Catalog resolves the resource bundle in the standard signed-app resource directory.
for bundle in "$BIN_DIR"/*.bundle; do
    [ -d "$bundle" ] && ditto "$bundle" "$APP/Contents/Resources/$(basename "$bundle")"
done
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>BioChemPet</string>
<key>CFBundleIdentifier</key><string>local.biochem.bridge</string>
<key>CFBundleName</key><string>BioChem Bridge</string>
<key>CFBundleDisplayName</key><string>BioChem 生化速查</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.5.0</string>
<key>CFBundleVersion</key><string>6</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><false/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
printf 'Built: %s\n' "$APP"

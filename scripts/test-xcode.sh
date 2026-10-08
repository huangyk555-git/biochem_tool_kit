#!/bin/bash
# Full Xcode required. Builds an exact source snapshot in a temporary directory:
# the UI runner only needs its bundle and temporary fixtures, not Documents access.
set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild -version
mkdir -p work
RESULT_ROOT="$(mktemp -d "$PWD/work/xcode-validation.XXXXXX")"
RUN_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/biochem-xcode.XXXXXX")"
mkdir -p "$RUN_ROOT/Source/biochem_tool_kit.xcodeproj"
for entry in Package.swift Sources Tests Checks UITests Config; do
    ditto "$entry" "$RUN_ROOT/Source/$entry"
done
cp biochem_tool_kit.xcodeproj/project.pbxproj "$RUN_ROOT/Source/biochem_tool_kit.xcodeproj/"
ditto biochem_tool_kit.xcodeproj/xcshareddata "$RUN_ROOT/Source/biochem_tool_kit.xcodeproj/xcshareddata"
# Preserve genuine results, including failing runs, after the runner exits.
trap 'if [[ -d "$RUN_ROOT/Tests.xcresult" ]]; then ditto "$RUN_ROOT/Tests.xcresult" "$RESULT_ROOT/Tests.xcresult"; fi' EXIT
printf 'Local test workspace: %s\n' "$RUN_ROOT"
printf '%s\n' "$RUN_ROOT" > "$RESULT_ROOT/workspace-path.txt"
COMMON=(-project "$RUN_ROOT/Source/biochem_tool_kit.xcodeproj" -scheme biochem_tool_kit -destination "platform=macOS,arch=$(uname -m)" -derivedDataPath "$RUN_ROOT/DerivedData" ONLY_ACTIVE_ARCH=YES)
xcodebuild "${COMMON[@]}" -configuration Debug build
xcodebuild "${COMMON[@]}" -configuration Debug -parallel-testing-enabled NO -resultBundlePath "$RUN_ROOT/Tests.xcresult" test
xcodebuild "${COMMON[@]}" -configuration Release build
printf 'Inspect XCTest, XCUITest and retained screenshot attachments: %s\n' "$RESULT_ROOT/Tests.xcresult"

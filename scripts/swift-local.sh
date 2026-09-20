#!/bin/bash
# Keep caches in the project. Work around an old private PackageDescription interface
# left by some Command Line Tools upgrades, using a compiler-local file overlay only.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/module-cache .build/cache
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
TOOLCHAIN="$(xcode-select -p)/usr/lib/swift/pm/ManifestAPI/PackageDescription.swiftmodule"
OVERLAY="$PWD/.build/manifest-interface-overlay.json"
python3 - "$TOOLCHAIN" "$OVERLAY" "$(xcode-select -p)/usr/include/swift" <<'PY'
import json, sys
from pathlib import Path
roots=[]
for private in Path(sys.argv[1]).glob('*.private.swiftinterface'):
    public=private.with_name(private.name.replace('.private.swiftinterface','.swiftinterface'))
    if public.exists() and 'public enum SwiftVersion' in private.read_text() and 'public typealias SwiftVersion' in public.read_text():
        roots.append({'type':'file','name':str(private),'external-contents':str(public)})
include=Path(sys.argv[3])
old=include/'module.modulemap'
new=include/'bridging.modulemap'
if old.exists() and new.exists() and old.read_text().split('module SwiftBridging',1)[-1] == new.read_text().split('module SwiftBridging',1)[-1]:
    empty=Path(sys.argv[2]).parent/'empty-legacy-modulemap'
    empty.write_text('// Duplicate legacy module map omitted for this compiler invocation.\n')
    roots.append({'type':'file','name':str(old),'external-contents':str(empty)})
Path(sys.argv[2]).write_text(json.dumps({'version':0,'roots':roots}))
PY
COMMAND="${1:-build}"
if [ "$#" -gt 0 ]; then shift; fi
exec swift "$COMMAND" --disable-sandbox --cache-path "$PWD/.build/cache" --manifest-cache local \
    -Xbuild-tools-swiftc -module-cache-path -Xbuild-tools-swiftc "$PWD/.build/corrected-manifest-cache" \
    -Xbuild-tools-swiftc -vfsoverlay -Xbuild-tools-swiftc "$OVERLAY" \
    -Xswiftc -vfsoverlay -Xswiftc "$OVERLAY" \
    -Xcc -ivfsoverlay -Xcc "$OVERLAY" "$@"

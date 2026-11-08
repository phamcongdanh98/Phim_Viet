#!/usr/bin/env bash
# Build đầy đủ: lõi Rust universal → app input method + app Cài đặt.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build_rust_universal.sh"
if [ "${USE_XCODE:-0}" = "1" ] && xcodebuild -version >/dev/null 2>&1 && command -v xcodegen >/dev/null; then
    cd "$ROOT/macos" && xcodegen generate
    xcodebuild -project PhimViet.xcodeproj -scheme PhimViet -configuration Release \
        CODE_SIGN_IDENTITY=- -derivedDataPath "$ROOT/build/xcode" build
    rm -rf "$ROOT/build/PhimViet.app"
    cp -R "$ROOT/build/xcode/Build/Products/Release/PhimViet.app" "$ROOT/build/"
else
    "$ROOT/scripts/build_bundle.sh"
fi

#!/usr/bin/env bash
# Chạy test Swift (swift-testing) cho PhimVietKit mà không cần Xcode/XCTest.
# SwiftPM trong Command Line Tools không chạy được bundle test (xem docs/DECISIONS.md D3),
# nên script tự biên dịch: PhimVietKit (thư viện tĩnh) + test → một file thực thi.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
O="$ROOT/build/swifttest"
mkdir -p "$O"
scripts/build_rust_universal.sh   # cargo tự bỏ qua nếu không có gì thay đổi

DEV="$(xcode-select -p)"
if [ -d "$DEV/Library/Developer/Frameworks/Testing.framework" ]; then
    FW="$DEV/Library/Developer/Frameworks"            # Command Line Tools
    PLUG="$DEV/usr/lib/swift/host/plugins/testing"
    INTEROP="$DEV/Library/Developer/usr/lib"
else
    PLAT="$DEV/Platforms/MacOSX.platform/Developer"   # Xcode
    FW="$PLAT/Library/Frameworks"
    PLUG="$DEV/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins/testing"
    INTEROP="$PLAT/usr/lib"
fi

cat > "$O/main.swift" <<'SWIFT'
import Testing
@main struct PhimVietTestRunner {
    static func main() async { await Testing.__swiftPMEntryPoint() as Never }
}
SWIFT

swiftc -parse-as-library -swift-version 5 -module-name PhimVietKit -enable-testing -I build/rust \
    -emit-library -static -emit-module -emit-module-path "$O/PhimVietKit.swiftmodule" \
    -o "$O/libPhimVietKit.a" \
    macos/PhimViet/Composition/*.swift macos/PhimViet/Shared/*.swift macos/PhimViet/EngineBridge.swift

swiftc -parse-as-library -swift-version 5 -module-name PhimVietKitTests \
    -F "$FW" -I build/rust -I "$O" -L "$O" -L build/rust -lPhimVietKit -lphimviet \
    -load-plugin-library "$PLUG/libTestingMacros.dylib" \
    -Xlinker -rpath -Xlinker "$FW" -Xlinker -rpath -Xlinker "$INTEROP" -framework Testing \
    macos/PhimVietTests/*.swift "$O/main.swift" -o "$O/run"

"$O/run" "$@"

#!/usr/bin/env bash
# Lắp build/PhimViet.app (universal arm64 + x86_64) chỉ với swiftc — không cần Xcode.
# Cần build/rust/libphimviet.a (scripts/build_rust_universal.sh).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

B="$ROOT/build"
APP="$B/PhimViet.app"
SET="$APP/Contents/Helpers/PhimVietSettings.app"
OBJ="$B/obj"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
VERSION="$(grep -m1 '^version' core/Cargo.toml | cut -d'"' -f2)"
BUILD_NUM="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
ARCHS=(arm64 x86_64)
SWIFTFLAGS=(-sdk "$SDK" -swift-version 5 -O -whole-module-optimization)

scripts/build_rust_universal.sh   # cargo tự bỏ qua nếu không có gì thay đổi

rm -rf "$APP" "$OBJ"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$SET/Contents/MacOS" "$SET/Contents/Resources" "$OBJ"

IME_SOURCES=(macos/PhimViet/*.swift macos/PhimViet/Composition/*.swift macos/PhimViet/Shared/*.swift)
SET_SOURCES=(macos/PhimVietSettings/*.swift macos/PhimViet/Settings/*.swift macos/PhimViet/Shared/*.swift)

for A in "${ARCHS[@]}"; do
    echo "• swiftc PhimViet ($A)"
    swiftc "${SWIFTFLAGS[@]}" -target "$A-apple-macos13.0" -module-name PhimViet \
        -I build/rust -L build/rust -lphimviet \
        -framework Cocoa -framework InputMethodKit -framework Carbon \
        "${IME_SOURCES[@]}" -o "$OBJ/PhimViet-$A"
    echo "• swiftc PhimVietSettings ($A)"
    swiftc "${SWIFTFLAGS[@]}" -target "$A-apple-macos13.0" -module-name PhimVietSettings -parse-as-library \
        -framework Cocoa -framework SwiftUI \
        "${SET_SOURCES[@]}" -o "$OBJ/PhimVietSettings-$A"
done

lipo -create "$OBJ"/PhimViet-{arm64,x86_64} -output "$APP/Contents/MacOS/PhimViet"
lipo -create "$OBJ"/PhimVietSettings-{arm64,x86_64} -output "$SET/Contents/MacOS/PhimVietSettings"

sed -e "s/\$(MARKETING_VERSION)/$VERSION/" -e "s/\$(CURRENT_PROJECT_VERSION)/$BUILD_NUM/" macos/PhimViet/Info.plist > "$APP/Contents/Info.plist"
sed -e "s/\$(MARKETING_VERSION)/$VERSION/" -e "s/\$(CURRENT_PROJECT_VERSION)/$BUILD_NUM/" macos/PhimVietSettings/Info.plist > "$SET/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
printf 'APPL????' > "$SET/Contents/PkgInfo"
cp -R macos/PhimViet/Resources/*.lproj "$APP/Contents/Resources/"

# Biểu tượng menu (template TIFF 16/32 px) vẽ lúc build.
[ -x "$B/make_icon" ] && [ "$B/make_icon" -nt scripts/make_icon.swift ] || swiftc -O scripts/make_icon.swift -o "$B/make_icon"
"$B/make_icon" "$APP/Contents/Resources/MenuIcon.tiff"

# Tiện ích đăng ký input source (dùng bởi install.sh / uninstall.sh).
[ -x "$B/pv-register" ] && [ "$B/pv-register" -nt scripts/pv_register.swift ] || \
    swiftc -O -framework Carbon scripts/pv_register.swift -o "$B/pv-register"

plutil -lint "$APP/Contents/Info.plist" "$SET/Contents/Info.plist" >/dev/null

# Ký ad-hoc: app con trước, app cha sau.
codesign --force --sign - --timestamp=none "$SET"
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --deep --strict "$APP"

echo "→ $APP ($(lipo -archs "$APP/Contents/MacOS/PhimViet"))"

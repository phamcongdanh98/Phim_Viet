#!/usr/bin/env bash
# Đóng gói build/PhimViet-<phiên bản>.dmg để cài không cần Xcode/Rust:
#   PhimViet.app · Cài đặt Phím Việt.command · Gỡ cài đặt Phím Việt.command · Hướng dẫn.txt
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VERSION="$(grep -m1 '^version' core/Cargo.toml | cut -d'"' -f2)"
scripts/build.sh
STAGE="$(mktemp -d)/Phím Việt"
mkdir -p "$STAGE"
cp -R build/PhimViet.app "$STAGE/"
cp macos/Installer/*.command macos/Installer/*.txt "$STAGE/"
chmod +x "$STAGE"/*.command
codesign --verify --deep --strict "$STAGE/PhimViet.app"
OUT="build/PhimViet-$VERSION.dmg"
rm -f "$OUT"
hdiutil create -volname "Phím Việt $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$OUT" >/dev/null
rm -rf "$(dirname "$STAGE")"
shasum -a 256 "$OUT" | tee "$OUT.sha256"
echo "→ $OUT ($(du -h "$OUT" | cut -f1))"

#!/usr/bin/env bash
# Cài Phím Việt vào ~/Library/Input Methods (không cần sudo).
#   scripts/install.sh [--select]   (--select: chọn luôn Phím Việt làm nguồn nhập hiện tại)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/PhimViet.app"
DEST="$HOME/Library/Input Methods"
REG="$ROOT/build/pv-register"

[ -d "$APP" ] || { echo "Chưa có $APP — chạy 'make build' trước."; exit 1; }
[ -x "$REG" ] || swiftc -O -framework Carbon "$ROOT/scripts/pv_register.swift" -o "$REG"

echo "• Dừng tiến trình cũ (nếu có)"
pkill -x PhimViet 2>/dev/null || true
pkill -x PhimVietSettings 2>/dev/null || true
sleep 0.5

mkdir -p "$DEST"
rm -rf "$DEST/PhimViet.app"
cp -R "$APP" "$DEST/"
xattr -dr com.apple.quarantine "$DEST/PhimViet.app" 2>/dev/null || true
echo "• Đã chép vào $DEST/PhimViet.app"

echo "• Đăng ký input source"
"$REG" register "$DEST/PhimViet.app" "$@" || true

cat <<MSG

✅ Đã cài Phím Việt.
Nếu chưa thấy trong menu nhập liệu:
  System Settings → Keyboard → Text Input → Input Sources → Edit… → "+"
  → Vietnamese → "Phím Việt" → Add.
Nếu vẫn không thấy: đăng xuất rồi đăng nhập lại (macOS lưu cache danh sách input method).
Chuyển Việt/Anh: nhấn rồi nhả ⌃⇧ (đổi được trong Cài đặt).
MSG

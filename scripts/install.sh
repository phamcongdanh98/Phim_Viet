#!/usr/bin/env bash
# Cài Phím Việt vào ~/Library/Input Methods (không cần sudo).
#   scripts/install.sh [--select] [--key]
#     --select: chọn luôn Phím Việt (bản gạch chân) làm nguồn nhập hiện tại
#     --key:    mở Phím Việt Key (app chạy riêng, không gạch chân — cần quyền Trợ năng)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/PhimViet.app"
DEST="$HOME/Library/Input Methods"
REG="$ROOT/build/pv-register"

[ -d "$APP" ] || { echo "Chưa có $APP — chạy 'make build' trước."; exit 1; }
[ -x "$REG" ] || swiftc -O -framework Carbon "$ROOT/scripts/pv_register.swift" -o "$REG"

OPEN_KEY=0
ARGS=()
for a in "$@"; do
    if [ "$a" = "--key" ]; then OPEN_KEY=1; else ARGS+=("$a"); fi
done
pgrep -x PhimVietKey >/dev/null 2>&1 && OPEN_KEY=1   # đang chạy → mở lại bản mới

echo "• Dừng tiến trình cũ (nếu có)"
pkill -x PhimVietKey 2>/dev/null || true
pkill -x PhimViet 2>/dev/null || true
pkill -x PhimVietSettings 2>/dev/null || true
sleep 0.5

mkdir -p "$DEST"
rm -rf "$DEST/PhimViet.app"
cp -R "$APP" "$DEST/"
xattr -dr com.apple.quarantine "$DEST/PhimViet.app" 2>/dev/null || true
echo "• Đã chép vào $DEST/PhimViet.app"

echo "• Đăng ký input source"
"$REG" register "$DEST/PhimViet.app" ${ARGS[@]+"${ARGS[@]}"} || true

KEYAPP="$DEST/PhimViet.app/Contents/Helpers/PhimVietKey.app"
if [ $OPEN_KEY = 1 ]; then
    # Bản build mới có chữ ký mới: quyền Trợ năng cũ không còn hiệu lực → xoá mục cũ để macOS hỏi lại.
    tccutil reset Accessibility com.phimviet.PhimVietKey >/dev/null 2>&1 || true
    open "$KEYAPP" && echo "• Đã mở Phím Việt Key — bật quyền Trợ năng khi macOS hỏi"
fi

cat <<MSG

✅ Đã cài Phím Việt.
Nếu chưa thấy trong menu nhập liệu:
  System Settings → Keyboard → Text Input → Input Sources → Edit… → "+"
  → Vietnamese → "Phím Việt" → Add.
Nếu vẫn không thấy: đăng xuất rồi đăng nhập lại (macOS lưu cache danh sách input method).
Chuyển Việt/Anh: nhấn rồi nhả ⌃⇧ (đổi được trong Cài đặt).

Muốn gõ KHÔNG gạch chân ở mọi app (Word, Chrome…): dùng Phím Việt Key
  make install-key   (hoặc: open "$KEYAPP")
  → bật quyền Trợ năng → chọn bàn phím ABC trên thanh menu (Phím Việt Key tự nghỉ khi chọn bộ gõ khác).
MSG

#!/bin/bash
# Cài Phím Việt từ file .dmg vào ~/Library/Input Methods (không cần mật khẩu admin).
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$DIR/PhimViet.app"
DEST="$HOME/Library/Input Methods"
APP="$DEST/PhimViet.app"
[ -d "$SRC" ] || { echo "Không thấy PhimViet.app cạnh file này."; exit 1; }

echo "• Dừng bản cũ (nếu có)"
pkill -x PhimVietKey 2>/dev/null || true
pkill -x PhimVietSettings 2>/dev/null || true
pkill -x PhimViet 2>/dev/null || true
sleep 0.5

mkdir -p "$DEST"
rm -rf "$APP"
cp -R "$SRC" "$DEST/"
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
echo "• Đã chép vào $APP"

"$APP/Contents/MacOS/pv-register" register "$APP" >/dev/null 2>&1 || true
echo "• Đã đăng ký bộ gõ"

cat <<'MSG'

✅ Đã cài Phím Việt. Có 2 cách dùng:

 1) Phím Việt (không cần cấp quyền, có thể gạch chân ở Word/Chrome):
    System Settings → Keyboard → Text Input → Input Sources → Edit… → "+"
    → Vietnamese → "Phím Việt" → Add. Rồi chọn Phím Việt trên thanh menu.
    (Chưa thấy trong danh sách: đăng xuất rồi đăng nhập lại.)

 2) Phím Việt Key (KHÔNG gạch chân ở mọi app, cần quyền Trợ năng):
    mở bằng câu hỏi bên dưới → bật quyền ở System Settings → Privacy & Security
    → Accessibility → Phím Việt Key → chọn bàn phím ABC trên thanh menu.

Chuyển Việt/Anh: nhấn rồi nhả ⌃ Control + ⇧ Shift.
MSG

read -r -p "Mở Phím Việt Key ngay bây giờ? [c/K] " ans || ans=""
case "$ans" in
    c|C|y|Y)
        tccutil reset Accessibility com.phimviet.PhimVietKey >/dev/null 2>&1 || true
        open "$APP/Contents/Helpers/PhimVietKey.app"
        echo "• Đã mở Phím Việt Key — bật quyền Trợ năng khi macOS hỏi."
        ;;
esac

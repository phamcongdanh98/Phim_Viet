#!/usr/bin/env bash
# Gỡ sạch Phím Việt.   scripts/uninstall.sh [--keep-settings]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/Library/Input Methods/PhimViet.app"
REG="$ROOT/build/pv-register"
BID="com.phimviet.inputmethod.PhimViet"

if [ -x "$REG" ] || swiftc -O -framework Carbon "$ROOT/scripts/pv_register.swift" -o "$REG" 2>/dev/null; then
    "$REG" disable "$BID" || true
fi
pkill -x PhimViet 2>/dev/null || true
pkill -x PhimVietSettings 2>/dev/null || true
pkill -x PhimVietKey 2>/dev/null || true
tccutil reset Accessibility com.phimviet.PhimVietKey >/dev/null 2>&1 || true   # xoá quyền Trợ năng đã cấp
rm -rf "$DEST"
echo "• Đã xoá $DEST"

if [ "${1:-}" != "--keep-settings" ]; then
    defaults delete "$BID" 2>/dev/null || true
    defaults delete com.phimviet.PhimVietSettings 2>/dev/null || true
    echo "• Đã xoá cài đặt (giữ lại bằng --keep-settings)"
fi
echo "✅ Đã gỡ Phím Việt. Có thể cần đăng xuất/đăng nhập để menu nhập liệu cập nhật."

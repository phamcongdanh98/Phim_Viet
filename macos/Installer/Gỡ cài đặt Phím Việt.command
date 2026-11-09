#!/bin/bash
# Gỡ Phím Việt khỏi ~/Library/Input Methods (giữ lại cài đặt của bạn).
set -uo pipefail
APP="$HOME/Library/Input Methods/PhimViet.app"
[ -x "$APP/Contents/MacOS/pv-register" ] && "$APP/Contents/MacOS/pv-register" disable com.phimviet.inputmethod.PhimViet >/dev/null 2>&1
pkill -x PhimVietKey 2>/dev/null
pkill -x PhimVietSettings 2>/dev/null
pkill -x PhimViet 2>/dev/null
tccutil reset Accessibility com.phimviet.PhimVietKey >/dev/null 2>&1
rm -rf "$APP"
echo "✅ Đã gỡ Phím Việt. Nếu tên còn hiện trong danh sách nguồn nhập: đăng xuất rồi đăng nhập lại."

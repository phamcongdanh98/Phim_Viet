#!/usr/bin/env bash
# Chứng minh input method (bản gạch chân) + app Cài đặt KHÔNG dùng CGEventTap / phím giả / quyền Accessibility
# (mã nguồn + file nhị phân). Ngoại lệ duy nhất: app chạy riêng macos/PhimVietKey (DECISIONS D12) —
# nằm trong Contents/Helpers, tiến trình riêng, người dùng tự mở.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
PATTERN='CGEventTap|CGEvent\(keyboardEventSource|CGEventPost|CGEventCreateKeyboardEvent|AXIsProcessTrusted|kAXTrustedCheckOptionPrompt|NSAccessibilityUsageDescription|IOHIDPostEvent|CGEventTapCreate'
fail=0
echo "• Tìm trong mã nguồn (trừ tài liệu và chính script này):"
if grep -rnE "$PATTERN" core ffi macos scripts --include='*.rs' --include='*.swift' --include='*.h' --include='*.c' --include='*.plist' | grep -v verify_no_eventtap | grep -v '^macos/PhimVietKey/'; then
    fail=1
else
    echo "  không có"
fi
APP="build/PhimViet.app"
if [ -d "$APP" ]; then
    echo "• Tìm ký hiệu trong file nhị phân:"
    for bin in "$APP/Contents/MacOS/PhimViet" "$APP/Contents/Helpers/PhimVietSettings.app/Contents/MacOS/PhimVietSettings"; do
        if nm -u "$bin" 2>/dev/null | grep -E 'CGEventTap|CGEventPost|CGEventCreateKeyboardEvent|AXIsProcessTrusted|IOHIDPostEvent'; then
            fail=1
        else
            echo "  $(basename "$bin"): không có"
        fi
    done
fi
[ $fail = 0 ] && echo "✅ Không dùng event tap / phím giả / Accessibility" || echo "❌ Phát hiện API cấm"
exit $fail

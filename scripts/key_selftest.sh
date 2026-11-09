#!/usr/bin/env bash
# Kiểm tra Phím Việt Key trên máy thật: gõ giả lập (PhimVietKey --selftest) vào
#   1) ô nhập Cocoa (tools/keytest/harness.swift)  2) Chrome riêng, profile tạm (--chrome)
# Yêu cầu: Phím Việt Key đang chạy, đã có quyền Trợ năng, nguồn nhập = ABC. Đừng chạm bàn phím/chuột khi chạy.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
K="$HOME/Library/Input Methods/PhimViet.app/Contents/Helpers/PhimVietKey.app/Contents/MacOS/PhimVietKey"
T="$(mktemp -d)"
KEYS="laf cuoocj giuwxa tieengs vieejt nam. delete data may <as "
WANT="là cuộc giữa tiếng việt nam. delete data mấy "
fail=0
swiftc -O "$ROOT/tools/keytest/harness.swift" -o "$T/harness" 2>/dev/null || { echo "build harness lỗi"; exit 1; }

"$T/harness" "$T/cocoa.log" & HP=$!; sleep 2
"$K" --selftest $HP "$KEYS"; rc=$?; sleep 1; kill $HP; wait $HP 2>/dev/null
GOT="$(grep '^text=' "$T/cocoa.log" | tail -1 | sed -e 's/^text=\[//' -e 's/\]$//')"
[ $rc = 0 ] && [ "$GOT" = "$WANT" ] && echo "✅ Cocoa: $GOT" || { echo "❌ Cocoa (exit $rc): [$GOT]"; fail=1; }

if [ "${1:-}" = "--chrome" ]; then
    python3 -I "$ROOT/tools/keytest/server.py" 8765 "$T/web.log" & SP=$!; sleep 1
    open -na "Google Chrome" --args --user-data-dir="$T/chrome" --no-first-run --no-default-browser-check \
        --new-window http://127.0.0.1:8765/test.html
    sleep 6
    CP=$(pgrep -f "user-data-dir=$T/chrome" | while read -r p; do ps -o args= -p "$p" | grep -q -- "--type=" || echo "$p"; done | head -1)
    "$K" --selftest "$CP" "$KEYS"; rc=$?; sleep 1.5
    GOT="$(grep '"input"' "$T/web.log" | tail -1 | python3 -I -c 'import json,sys; print(json.loads(sys.stdin.read())["value"])')"
    [ $rc = 0 ] && [ "$GOT" = "$WANT" ] && echo "✅ Chrome: $GOT" || { echo "❌ Chrome (exit $rc): [$GOT]"; fail=1; }
    kill "$CP" "$SP" 2>/dev/null; wait "$SP" 2>/dev/null
fi
rm -rf "$T"
exit $fail

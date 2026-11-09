#!/usr/bin/env bash
# Sinh core/data/en_double.txt từ /usr/share/dict/words (Webster's 2nd, 1934 — hết bản quyền).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
{
    echo "# Từ tiếng Anh (4–14 chữ) chứa cặp phím đôi Telex (ss ff rr xx jj dd aa ee oo ww) — trích từ /usr/share/dict/words"
    echo "# (Webster's Second International, 1934 — hết bản quyền). Sinh lại: scripts/gen_en_double.sh"
    # Từ 3 chữ thông dụng (không thêm `ass`: đặc tả dùng `ass` → `as` làm ví dụ huỷ dấu).
    { grep -E '^[a-z]{4,14}$' /usr/share/dict/words | grep -E 'ss|ff|rr|xx|jj|dd|aa|ee|oo|ww'
      printf '%s\n' off err add odd; } | LC_ALL=C sort -u
} > "$ROOT/core/data/en_double.txt"

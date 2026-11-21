#!/usr/bin/env bash
# Tạo chứng chỉ ký mã TỰ KÝ "Phim Viet Code Signing" trong Keychain đăng nhập của máy này (một lần).
# Mục đích: mọi bản build ký cùng một danh tính → macOS giữ quyền Trợ năng của Phím Việt Key qua các lần cập nhật
# (ký ad-hoc thì mỗi bản build là "app mới"). Không phải chứng chỉ Apple: máy khác vẫn cần "Open Anyway".
# Khoá riêng chỉ nằm trong Keychain; file tạm bị xoá ngay. KHÔNG commit khoá/chứng chỉ vào repo.
set -euo pipefail
NAME="Phim Viet Code Signing"
KC="$HOME/Library/Keychains/login.keychain-db"

if security find-certificate -c "$NAME" "$KC" >/dev/null 2>&1; then
    echo "Đã có chứng chỉ \"$NAME\" — không tạo lại."
    exit 0
fi

T="$(mktemp -d)"
trap 'rm -f "$T/key.pem" "$T/cert.pem" "$T/id.p12" "$T/openssl.cnf"; rmdir "$T" 2>/dev/null || true' EXIT
cat > "$T/openssl.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$T/openssl.cnf" \
    -keyout "$T/key.pem" -out "$T/cert.pem" 2>/dev/null
PASS="$(openssl rand -hex 16)"
openssl pkcs12 -export -inkey "$T/key.pem" -in "$T/cert.pem" -name "$NAME" \
    -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 \
    -out "$T/id.p12" -passout "pass:$PASS" 2>/dev/null
# -T: cho phép codesign dùng khoá mà không hỏi mỗi lần.
security import "$T/id.p12" -k "$KC" -P "$PASS" -T /usr/bin/codesign >/dev/null
echo "✅ Đã tạo chứng chỉ \"$NAME\" trong Keychain đăng nhập."

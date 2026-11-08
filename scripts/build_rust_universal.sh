#!/usr/bin/env bash
# Build lõi Rust thành thư viện tĩnh universal (arm64 + x86_64): build/rust/libphimviet.a
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/rust"
export MACOSX_DEPLOYMENT_TARGET=13.0
mkdir -p "$OUT"
cd "$ROOT"
for T in aarch64-apple-darwin x86_64-apple-darwin; do
    rustup target list --installed | grep -qx "$T" || rustup target add "$T"
    cargo build --release -p phimviet-ffi --target "$T"
done
lipo -create \
    "target/aarch64-apple-darwin/release/libphimviet.a" \
    "target/x86_64-apple-darwin/release/libphimviet.a" \
    -output "$OUT/libphimviet.a"
cp ffi/include/phimviet.h ffi/include/module.modulemap "$OUT/"
echo "→ $OUT/libphimviet.a ($(lipo -archs "$OUT/libphimviet.a"))"

# Phím Việt — make test | make build | make install | make uninstall
.PHONY: all test rust-test swift-test ffi-test lint build install install-select install-key key-selftest dmg uninstall clean bench verify xcode

all: build

test: rust-test lint rust-lib ffi-test swift-test

rust-test:
	cargo test --workspace
	cargo test --workspace --release

lint:
	cargo clippy --workspace --all-targets -- -D warnings
	cargo fmt --all -- --check

rust-lib:
	scripts/build_rust_universal.sh

ffi-test: rust-lib
	clang -mmacosx-version-min=13.0 ffi/tests/ffi_smoke.c -Iffi/include -Lbuild/rust -lphimviet -o build/ffi_smoke
	build/ffi_smoke

swift-test: rust-lib
	scripts/swift_test.sh

bench:
	cargo test -p phimviet-core --release --test bench -- --ignored bench --nocapture

build:
	scripts/build.sh

install: build
	scripts/install.sh

install-select: build
	scripts/install.sh --select

# Cài và mở Phím Việt Key (app chạy riêng, không gạch chân, cần quyền Trợ năng).
install-key: build
	scripts/install.sh --key

# Bộ cài .dmg (build/PhimViet-<phiên bản>.dmg) cho máy không có Xcode/Rust.
dmg:
	scripts/make_dmg.sh

# Gõ thử thật qua Phím Việt Key (cần quyền Trợ năng, nguồn nhập ABC; đừng chạm bàn phím khi chạy).
key-selftest:
	scripts/key_selftest.sh --chrome

uninstall:
	scripts/uninstall.sh

# Kiểm tra trước khi commit/phát hành: test + build + bằng chứng không dùng API cấm.
verify: test build
	scripts/verify_no_eventtap.sh

xcode:
	cd macos && xcodegen generate

clean:
	cargo clean
	rm -rf build .build

# Phím Việt — make test | make build | make install | make uninstall
.PHONY: all test rust-test swift-test ffi-test lint build install install-select uninstall clean bench verify xcode

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

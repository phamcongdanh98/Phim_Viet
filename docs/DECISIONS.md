# Nhật ký quyết định (DECISIONS)

Mỗi mục: **Bối cảnh → Quyết định → Lý do**. Mục mới thêm ở cuối.

## D1. Khảo sát môi trường (2026-11-08)

| Công cụ | Kết quả |
|---|---|
| macOS | 27.3 (build 26C5035r), arm64 |
| `xcodebuild -version` | **Không có Xcode** — chỉ có Command Line Tools (`/Library/Developer/CommandLineTools`) |
| `swiftc` | Apple Swift 6.4.2, SDK `MacOSX27.2.sdk` |
| XCTest | **Không có** (XCTest.framework chỉ đi kèm Xcode) |
| swift-testing (`import Testing`) | **Có** trong CLT — `swift test` chạy được |
| `cargo` / `rustc` | 1.98.1; đã thêm target `x86_64-apple-darwin` (đã có `aarch64-apple-darwin`) |
| `brew` | Có (`/opt/homebrew`) |
| `xcodegen` | Chưa cài — **không cài** vì không có `xcodebuild` thì vô dụng |
| `/usr/share/dict/words` | Có |

## D2. Build không cần Xcode

- **Quyết định:** đường build chính là `scripts/build_bundle.sh`: `swiftc` biên dịch từng kiến trúc (`arm64`, `x86_64`, `-target …-apple-macos13.0`), `lipo` gộp, tự lắp `.app` (Info.plist, `MacOS/`, `Resources/`), ký ad-hoc `codesign -s -`.
- `macos/project.yml` (XcodeGen) vẫn được viết để ai có Xcode thì dùng (`make xcode`), nhưng **chưa được kiểm chứng** trên máy này.
- **Lý do:** máy chỉ có CLT; đặc tả cho phép phương án này.

## D3. Test Swift: swift-testing thay cho XCTest

- **Quyết định:** logic trình bày chữ (`DirectEdit`, `CompositionSession`, `ClientTrust`, presenter) nằm trong module thuần Foundation `PhimVietComposition` (SwiftPM, `macos/Package.swift`), giao tiếp với app qua protocol `TextClient`. Test bằng **swift-testing** (`swift test`), với các client giả "xấu".
- App thật biên dịch cùng các file nguồn đó + adapter `IMKTextClient` bọc `IMKTextInput`.
- **Lý do:** XCTest không có trong CLT; swift-testing có và chạy được. Tách protocol giúp test không cần InputMethodKit.

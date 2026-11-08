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

## D3. Test Swift: swift-testing thay cho XCTest, chạy bằng script

- **Quyết định:** logic trình bày chữ (`DirectEdit`, `CompositionSession`, `ClientTrust`, presenter, cài đặt,
  phím chuyển V/E) nằm trong module thuần Foundation **`PhimVietKit`** (`macos/PhimViet/{Composition,Shared}` +
  `EngineBridge.swift`), giao tiếp với app qua protocol `TextClient`. Test bằng **swift-testing** với các client giả
  "xấu" (`macos/PhimVietTests/FakeClient.swift`), dùng engine Rust thật.
- **Cách chạy:** `scripts/swift_test.sh` (gọi trong `make test`): `swiftc` biên dịch PhimVietKit thành thư viện tĩnh,
  rồi biên dịch test + entry point `Testing.__swiftPMEntryPoint()` thành một file thực thi.
- **Lý do:** XCTest không có trong CLT. `swift test` của SwiftPM 6.x trong CLT: hệ build mới không nạp được plugin
  `TestingMacros` (dùng explicit modules), hệ build `native` build được nhưng không chạy bundle test khi thiếu XCTest.
  `Package.swift` vẫn giữ ở gốc repo cho người có Xcode (`swift test`), nhưng không phải đường chính.
- App thật biên dịch cùng các file nguồn đó (một module) + adapter `IMKTextClient` bọc `IMKTextInput`.

## D4. Engine: các quyết định hành vi (chi tiết ở ENGINE_RULES.md)

| Vấn đề | Quyết định | Lý do |
|---|---|---|
| `ươ` vs `uơ` khi chưa có âm cuối | `uo`+`w` → móc `u` "ngầm định"; không có chữ sau `ơ` → hiện `uơ` (`thuở`, `huơ`); có âm cuối → `ươ` | `ươ` không bao giờ đứng cuối; `uơ` chỉ có ở `thuở/huơ/khuơ`. Gõ `nguowi` thoáng hiện `nguơ` rồi thành `ngươi` — chấp nhận để chuỗi hiển thị luôn bằng chuỗi chốt |
| `xoong` | `xoong` → `xông`; muốn `xoong` gõ `xooong` | `ông/ôc` phổ biến hơn rất nhiều |
| `did` | → `đi` (phím `d` thứ hai gõ tự do) | Nhất quán với gõ dấu tự do |
| Gõ đúp ở cuối từ (`ass`, `pass`) | Nếu người dùng đã *thấy* biến đổi và kết quả sau huỷ là ASCII → giữ (`ass`→`as`, `pass`→`pas`); ở giữa từ (`issue`) → khôi phục phím thô | Không phân biệt được `pass` (Anh) với `ass`→`as` (huỷ có chủ ý) nếu không có từ điển; ưu tiên quy tắc 4 của đặc tả |
| Từ không có nguyên âm (`đ`, `đc`) | Không kiểm tra, không khôi phục | Viết tắt phổ biến khi chat; `dd` → `đ` |
| Từ hợp lệ cả hai ngôn ngữ (`test`→`tét`, `this`→`thí`, `if`→`ì`) | Giữ tiếng Việt | Đặc tả mục 6; ghi ở KNOWN_ISSUES |
| Chữ số khi VNI | Chỉ là phím khi đang có từ dở | Gõ số độc lập không bị nuốt |
| Từ > 64 phím | Đóng băng (không biến đổi thêm) | Chặn chi phí O(n²) khi giữ phím lặp |

## D5. Shell: cửa sổ Cài đặt là app riêng nhúng trong bundle

- **Bối cảnh:** đặc tả gợi ý mở cửa sổ SwiftUI ngay trong tiến trình input method (tạm đổi activation policy).
- **Quyết định:** Cài đặt là app riêng `PhimVietSettings.app` nằm trong `PhimViet.app/Contents/Helpers/`.
  Menu "Cài đặt…", "Gõ tắt…", "Giới thiệu" mở app này bằng `NSWorkspace`.
  Hai tiến trình dùng chung domain `UserDefaults` `com.phimviet.inputmethod.PhimViet`; Cài đặt ghi xong thì
  phát `DistributedNotification` `com.phimviet.inputmethod.PhimViet.preferencesChanged`, input method đọc lại
  và áp dụng ngay (không cần khởi động lại).
- **Lý do:** ô nhập liệu (bảng gõ tắt) nằm cùng tiến trình với IMK server có nguy cơ treo (client và server
  cùng run loop chính, gọi đồng bộ). Input method `LSBackgroundOnly` cũng không có Dock/menu bar để quản lý cửa sổ.
  App riêng loại bỏ hẳn rủi ro này và chạy như app bình thường (Dark Mode, focus bàn phím).

## D6. Trình bày chữ: chứng minh trước khi gõ trực tiếp

- App chưa biết → dùng **Marked** cho từ đầu tiên. Khi chốt từ đó, đọc lại tài liệu
  (`selectedRange` + `attributedSubstring`) — khớp chính xác (so từng đơn vị UTF-16, không so tương đương
  Unicode) → app được tin, từ sau dùng **Direct**. Không khớp → Marked cho app đó tới hết phiên.
- Direct: mỗi lần cần thay (không chỉ thêm đuôi) đều đọc và so khớp lại; sai → bỏ từ, rút quyền.
- Backspace khi Direct: engine luôn xoá đúng 1 ký tự hiển thị cuối → **để ứng dụng tự xoá** (trả phím cho app),
  chỉ cập nhật `shown`. Không cần đọc tài liệu, giữ được lịch sử hoàn tác của app.
- Click/đổi app khi Direct: chỉ "quên" từ (không sửa tài liệu vì con trỏ đã đổi), nên tự khôi phục tiếng Anh
  chỉ áp dụng khi kết thúc từ bằng phím.

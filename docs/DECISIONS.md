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

- App chưa biết → dùng **Marked**. Khi chốt mỗi từ: con trỏ phải nằm đúng tại `markedRange().location` (lấy
  trước khi chèn) + độ dài chữ chèn, và đọc lại chữ ngay trước con trỏ khớp chính xác (so từng đơn vị UTF-16,
  không so tương đương Unicode). Cần **hai lần thành công ở hai vị trí khác nhau** mới được tin (app báo con trỏ
  sai cố định chỉ trùng hợp được ở một vị trí — lỗi do rà soát độc lập tìm ra). Thất bại → Marked tới hết phiên.
- Direct: trước mỗi lần thay (không chỉ thêm đuôi) đọc và so khớp; **sau mỗi lần ghi** kiểm tra con trỏ dịch đúng độ dài
  vừa ghi, sau khi thay còn đọc lại cả từ. Sai trước khi ghi → bỏ từ; sai sau khi ghi → kết thúc từ; cả hai đều rút quyền.
- Backspace khi Direct: engine luôn xoá đúng 1 ký tự hiển thị cuối → **để ứng dụng tự xoá** (trả phím cho app),
  chỉ cập nhật `shown`. Không cần đọc tài liệu, giữ được lịch sử hoàn tác của app.
- Backspace khi có vùng chọn sau con trỏ (gợi ý tự hoàn thành): không trả cho app (app chỉ xoá phần gợi ý) mà sửa
  qua bước kiểm chứng.
- Click khi Marked: chỉ chốt nếu `markedRange()` vẫn còn (app có thể đã tự chốt → chèn lại sẽ nhân đôi chữ).
- Click/đổi app khi Direct: chỉ "quên" từ (không sửa tài liệu vì con trỏ đã đổi), nên tự khôi phục tiếng Anh
  chỉ áp dụng khi kết thúc từ bằng phím.

## D7. Phím thô sau Backspace

- **Bối cảnh:** sau Backspace engine dựng lại raw chuẩn (ví dụ `nguoi72` ⌫ → raw `ngu7o72`); phím thô gốc không còn
  tương ứng với chữ còn lại.
- **Quyết định:** ESC và tự khôi phục sau Backspace dùng **raw chuẩn dựng lại** (ghi ở ENGINE_RULES §8–9).
- **Lý do:** không có cách ánh xạ "phím đã gõ" sang chữ còn lại sau khi xoá; raw chuẩn luôn gõ lại ra đúng chữ đang
  hiển thị, và thường chính là chuỗi tiếng Anh người dùng muốn (`tẽt` ⌫ `t` → khôi phục `text`).

## D8. Kết quả rà soát độc lập (subagent)

11 vấn đề; đã sửa 10, 1 ghi thành quy tắc (D7). Mỗi lỗi có test hồi quy:

| # | Vấn đề | Xử lý | Test |
|---|---|---|---|
| 1 | Con trỏ sai cố định + từ ngắn → được tin → ghi đè | Chứng minh cần con trỏ đúng + 2 vị trí; kiểm tra con trỏ sau mỗi lần ghi | `constantLyingCaretWithShortWordIsNeverTrusted` |
| 2 | Không kiểm tra sau khi thay; app bỏ qua `replacementRange` | Đọc lại sau khi thay → rút quyền ngay | `appIgnoringReplacementRangeLosesTrustImmediately`, `replacementIgnoredByAppIsDetected` |
| 3 | Marked bị chèn lại khi app đã tự chốt lúc click | Kiểm tra `markedRange()` | `markedTextAlreadyCommittedByAppIsNotInsertedTwice` |
| 4 | Backspace khi có gợi ý bôi đen | Không trả cho app khi có vùng chọn | `backspaceWithSelectedSuggestionIsHandledByIME` |
| 5 | `dduwocj`, `nguwoif`, `truwongf` | `ư` + `o` + chữ sau → `ươ` | `hard_cases` |
| 6 | `thuwowr` chốt ra phím thô | Sửa nhẹ lúc chốt (`commit_fix`) | `hard_cases` |
| 7 | Thiếu `quắp`, `quạo`, `quạu` | Thêm vần `ăp ao au` sau `qu` | `hard_cases` |
| 8 | Phím thô sau Backspace là raw dựng lại | Quy tắc D7 | — |
| 9 | `Ww` → `w` | Giữ hoa/thường của phím `w` đầu | `hard_cases` |
| 10 | Gõ tắt NFD | `chars::nfc` khi nạp gõ tắt | `macros`, `nfc_composes_vietnamese` |
| 11 | Script không build lại Rust | Luôn gọi `build_rust_universal.sh` (cargo tự bỏ qua) | — |

## D9. Phản hồi thử thật trên Chrome (2026-11-08)

- **Nhầm tên tuỳ chọn:** người dùng "tắt" mục *Gõ không gạch chân* với ý tắt gạch chân → thực tế bật gạch chân.
  Đổi thành **"Gạch chân chữ đang gõ"** (có dấu tích = có gạch chân); dữ liệu lưu vẫn là `directTyping` (đảo nghĩa ở UI).
- **Marked text bị tô nền trong Chrome:** gửi `NSAttributedString` gạch chân mảnh (`NSUnderlineStyle.single`) thay vì chuỗi trơn.
- **App báo trễ (Chromium/Electron cập nhật vị trí con trỏ bất đồng bộ):** kiểm tra ngay sau khi ghi sẽ rút quyền nhầm.
  Nay: con trỏ đúng ngay → xong; con trỏ *chưa đổi* → lưu `Pending` và kiểm ở lần sửa/phím kế tiếp (trước khi ghi);
  con trỏ ở chỗ khác → rút quyền. App báo sai vẫn bị bắt (chậm một phím). Test `laggingChromiumLikeAppStillTypesDirect`,
  `laggingAppThatLiesIsStillCaught`, `leftoverWriteIsVerifiedOnNextWord`.

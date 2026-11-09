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
- **Chrome báo `markedRange()` theo toạ độ riêng** → chứng minh sai từ từ thứ hai. Nay chứng minh chỉ dựa vào
  `selectedRange()` + đọc lại sau khi chốt (vẫn cần 2 vị trí khác nhau). Test `chromeLikeMarkedRangeStillProves`.
- **⌘A phải bấm 2 lần trên Chrome:** chốt marked text trong lúc xử lý keyDown của phím tắt làm Chrome bỏ qua phím tắt.
  Nay chốt ngay khi `flagsChanged` báo vừa nhấn ⌘/⌃/⌥ (trước keyDown).
- Sự kiện chẩn đoán (không có nội dung gõ) ghi mức `notice` để `log show` đọc lại được.

## D10. Chrome lần 2 + sửa dấu từ trước (2026-11-09)

- **Log thực tế:** `trust.failed` ngay từ đầu tiên trên Chrome. Theo mã nguồn Chromium, `selectedRange` là giá trị đệm
  cập nhật bất đồng bộ, còn `attributedSubstringForProposedRange` là IPC đồng bộ → đọc lại ngay sau khi chèn lệch nhau.
  **Sửa:** chứng minh thất bại ngay thì hoãn (`trust.deferred`), kiểm lại ở phím kế tiếp (`ClientTrust.proveLater`,
  cho phép app đã chèn thêm ≤2 ký tự kết thúc từ). Log kèm số liệu chẩn đoán (vị trí, độ dài — không nội dung) và bundle id.
- **Sửa dấu từ trước** (trước đây nằm ngoài phạm vi v1, người dùng yêu cầu): sau khi ⌫ đi qua ranh giới từ, phím chữ tiếp theo
  đọc từ ngay trước con trỏ, `pv_load_word` nạp lại (chỉ khi raw chuẩn gõ ra đúng từ đó — từ tiếng Anh như `with`, `data`
  không được nạp), rồi tiếp tục bằng Direct với kiểm chứng như thường. Chỉ ở app đã được tin; chế độ gạch chân không có.

## D11. Chrome lần 3: `length() = 0`; huỷ dấu khi tắt kiểm tra âm tiết (2026-11-09)

- **Log thực tế sau D10:** Chrome và VSCode đã được tin (`trust.proved.late` ×2) nhưng ngay lần thay chữ đầu tiên lại
  `direct.abandon`, chẩn đoán `documentTooShort ... doc=0`. Chromium/Electron trả `length() = 0` cho IMK (không hỗ trợ),
  nên kiểm tra "tài liệu ngắn hơn vị trí con trỏ" luôn trượt → bỏ từ, rút quyền → quay về gạch chân.
  **Sửa:** `length() = 0` được coi là "không biết" (`DirectEdit.verifiedRegion`); an toàn vẫn dựa vào đọc lại đúng chữ
  trước con trỏ (đọc sai → `mismatch`, không ghi). Độ dài > 0 nhưng ngắn hơn con trỏ vẫn bị chặn như cũ.
  Log `direct.abandon`/`direct.unverified` nay kèm lý do + số liệu.
- **`delete` → `delte` khi tắt kiểm tra âm tiết:** phím `e` cuối được coi là "huỷ tường minh" (vì tắt kiểm tra thì mọi
  biến đổi đều hiện ra) nên không khôi phục. Nay huỷ tường minh cần: biến đổi bị huỷ là chữ Việt hợp lệ, hoặc gõ lặp
  ngay (`aaa`, `ss`). Bộ 309 từ tiếng Anh khi tắt kiểm tra âm tiết: 295 → 297 (`delete`, `border`).

## D12. Thêm Phím Việt Key — app chạy riêng, không gạch chân (2026-11-09, người dùng quyết định)

- **Bối cảnh:** người dùng vẫn thấy gạch chân ở Word và Chrome. Tìm hiểu: mọi bộ gõ tiếng Việt "không gạch chân" phổ biến
  (OpenKey, EVKey, GoTiengViet, Gõ Nhanh, goxkey) đều là **app chạy riêng** dùng `CGEventTap` + gửi ⌫ giả + quyền Trợ năng;
  bộ gõ tiếng Việt mặc định của Apple (InputMethodKit) cũng gạch chân. Với InputMethodKit, bỏ gạch chân chỉ an toàn khi
  app cho đọc lại văn bản chính xác — Word và một số ô Chromium không đáp ứng → giới hạn của cách làm, không phải lỗi.
- **Quyết định (người dùng chọn):** giữ nguyên Phím Việt (IMK, nguyên tắc cũ không đổi) và **thêm** Phím Việt Key —
  một app chạy riêng, người dùng tự mở và tự cấp quyền. Đây là ngoại lệ có chủ đích đối với nguyên tắc "không event tap /
  không phím giả / không Accessibility" của đặc tả ban đầu; nguyên tắc đó vẫn áp dụng cho input method và app Cài đặt
  (`verify_no_eventtap.sh` chỉ miễn `macos/PhimVietKey`).
- **Thiết kế:** dùng chung engine Rust + cài đặt; logic quyết định (`TapSession`) thuần, test bằng ứng dụng giả.
  Không đọc tài liệu: chỉ nhớ chữ chính mình đã gõ cho từ hiện tại; click / ⌘⌃⌥ / phím điều hướng / đổi app → quên từ.
  Chỉ gửi phím giả khi chữ khác phím vừa gõ. Tự nghỉ khi nguồn nhập không phải bố cục bàn phím (tránh gõ chồng với IMK).
  Cách gửi theo app (ý tưởng tham khảo từ tài liệu kiến trúc Gõ Nhanh, BSD-3; mã tự viết): trình duyệt gõ trước U+202F để
  huỷ gợi ý bôi đen; Office/Electron/terminal chèn độ trễ.
- **Vị trí cài:** `~/Library/Input Methods/PhimViet.app/Contents/Helpers/PhimVietKey.app` (giữ ràng buộc chỉ ghi vào thư mục
  dự án và `~/Library/Input Methods`). Người dùng có thể kéo ra `/Applications` nếu muốn.
- **Chữ ký ad-hoc:** mỗi lần build lại macOS coi là app mới → phải bật lại quyền Trợ năng; `install.sh --key` chạy
  `tccutil reset Accessibility com.phimviet.PhimVietKey` để xoá mục cũ.
- **Lỗi đầu tiên trên máy thật (2026-11-09):** `laf` → `laà`, `cuoocj` → `cuoôộc`. Đoán ban đầu (macOS gộp các ⌫ vì thiếu
  `maskNonCoalesced`) là **sai**. Dựng lại được bằng `PhimVietKey --selftest` + ô nhập Cocoa ghi log từng phím: phím gốc
  (`f`) tới app trước, ⌫ xoá nhầm chính nó. Gốc: `tap.handler = { self?.handle(...) ?? event }` — khi `handle` trả `nil`
  (nuốt phím), `??` trả lại phím gốc → không phím nào bị nuốt. Đã sửa; `scripts/key_selftest.sh --chrome`
  (`make key-selftest`) kiểm tra trên ô Cocoa và Chrome riêng (profile tạm): cả tap HID lẫn session đều đúng.
  Mặc định chọn tap HID (như Gõ Nhanh); `defaults write com.phimviet.PhimVietKey tap session|hid`,
  `freshSource`, `flags`, `preDelay`, `trace` để đo khi cần.
- `--selftest` chỉ gõ chuỗi cố định gồm a–z, số, cách, dấu chấm, ⌫ (≤120 phím) và kiểm tra trước MỖI phím rằng app test
  (pid) đang ở trên cùng — sai thì dừng, không gõ vào app khác.

## D13. Gõ đôi để huỷ dấu giữa từ + danh sách từ tiếng Anh có chữ đôi (2026-11-09)

- **Vấn đề (người dùng báo):** gõ `tesst` để được `test` (vì `test` → `tét`) nhưng ra `tesst`: đuôi huỷ kết thúc khi gõ `t`,
  từ không hợp lệ → khôi phục phím thô. Đồng thời `pass/less/miss` → `pas/les/mis` (E2), và khi tắt kiểm tra âm tiết
  `class/success/address/process` cũng bị huỷ dấu; `basis/oasis` → `bais/oais` (hai `s` cách nhau bị coi là huỷ).
- **Quyết định:** (1) huỷ tường minh phải gõ **liền**; (2) ghi nhớ "đã gõ đôi để huỷ" cho cả từ (`deliberate_undo`);
  (3) khi chốt, phân biệt bằng danh sách từ tiếng Anh có chữ đôi (`core/data/en_double.txt`, ~24k từ, 260 KB, nguồn
  Webster 1934 hết bản quyền): có trong danh sách → phím thô, không có → chữ đã huỷ. (4) ⌫ ưu tiên bỏ phím cuối nếu nó
  tạo đúng ký tự vừa xoá, giữ lịch sử gõ (`issu` ⌫ `ue` → `issue`).
- **Đánh đổi:** `ass` vẫn → `as` (ví dụ của đặc tả, không đưa vào danh sách). Từ tiếng Anh không có trong danh sách và
  có gõ đôi phím dấu sẽ bị huỷ dấu. Không đổi gì khi không có gõ đôi.
- **Kết quả:** bộ 309 từ IT 299/309 ở cả hai chế độ kiểm tra âm tiết (trước: 298 / 297); từ điển ≤10 ký tự 99,31%
  (trước 99,25% / 99,09%); số từ ra chữ ASCII sai 92 → 9 (còn lại: `ass` theo đặc tả và từ hiếm có `z`).
  Tốc độ 1,49 µs/phím.


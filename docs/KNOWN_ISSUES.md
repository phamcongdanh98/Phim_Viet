# Giới hạn & vấn đề đã biết

## Engine

| # | Vấn đề | Ví dụ | Cách xử lý / lý do |
|---|---|---|---|
| E1 | Từ vừa là âm tiết tiếng Việt hợp lệ vừa là từ tiếng Anh được giữ tiếng Việt | `mix→mĩ`, `box→bõ`, `test→tét`, `this→thí`, `if→ì`, `list→lít`, `rust→rút`, `reset→rết`, `theme→thêm`, `row→rơ`, `var→vả`, `how→hơ` | Không có từ điển nên không phân biệt được. Dùng ⌃⇧ chuyển sang E, hoặc ESC để lấy phím thô, hoặc đặt app hay gõ code vào "Luôn gõ tiếng Anh". Tỷ lệ khôi phục trên bộ 300 từ IT: 96,7%; trên `/usr/share/dict/words` (≤10 ký tự): 99,2% |
| E2 | Gõ đúp ở **cuối** từ tiếng Anh bị hiểu là huỷ dấu | `pass→pas`, `less→les`, `miss→mis` | Không phân biệt được với `ass→as` (huỷ có chủ ý theo đặc tả). Gõ đúp ở giữa từ (`issue`, `lesson`) vẫn khôi phục đúng |
| E3 | `xoong`, `boong` cần gõ `xooong` | `xoong→xông` | `ông/ôc` phổ biến hơn rất nhiều |
| E4 | `dd` luôn thành `đ` (kể cả khi chốt) | lệnh `dd` | Gõ `ddd` → `dd` |
| E5 | Gõ `uo`+`w` khi chưa có âm cuối hiện `uơ`, có âm cuối mới thành `ươ` | `nguowi`: `nguơ` → `ngươi` | Chuỗi hiển thị luôn bằng chuỗi sẽ chốt; nháy chữ `u` một lần. Gõ `nguoiw` không nháy |
| E6 | Từ đang gõ trông "lạ" trong lúc gõ tiếng Anh | `data` hiện `dât` trước khi chốt | Khi chốt sẽ khôi phục `data` |
| E7 | Một số vần hiếm được chấp nhận rộng (ví dụ `coa`, `boa`) | — | Bảng vần ưu tiên không chặn nhầm từ thật/mượn |
| E8 | Từ > 64 phím bị "đóng băng" (không biến đổi thêm) | giữ phím lặp | Chặn chi phí O(n²) |
| E9 | ESC / tự khôi phục sau Backspace dùng phím thô dựng lại | `nguoi72` ⌫ ESC → `ngu7o72` | DECISIONS D7 |

## Shell macOS

| # | Vấn đề | Chi tiết |
|---|---|---|
| S1 | Hai từ đầu tiên trong mỗi app (mỗi phiên) luôn gạch chân | App phải chứng minh đọc lại đúng ở hai vị trí khác nhau trước khi được gõ trực tiếp (DECISIONS D6) |
| S1b | App đã được tin nhưng sau đó bỏ qua `replacementRange` có thể làm sai **một** từ | Kiểm tra sau khi ghi phát hiện ngay và rút quyền; các từ sau dùng gạch chân |
| S2 | Tin/không tin tính theo **cả app** (bundle id) | Nếu một ô của app không đọc được (ví dụ thanh URL), cả app về chế độ gạch chân tới khi khởi động lại input method (`pkill -x PhimViet` hoặc đăng xuất) |
| S3 | Khi gõ trực tiếp, click chuột / đổi app giữa từ thì **không** tự khôi phục tiếng Anh cho từ đó | Con trỏ đã đổi nên không sửa tài liệu (an toàn hơn) |
| S4 | Terminal/iTerm2 thường luôn ở chế độ gạch chân | Các app này không cho đọc nội dung — đúng thiết kế, không ghi đè |
| S5 | Phím có ⌥ Option được trả cho app (chốt từ trước) | Bàn phím dùng ⌥ để gõ ký tự đặc biệt vẫn hoạt động, nhưng không đi qua engine |
| S6 | Chỉ kiểm tra với bố cục bàn phím ABC/US | Bố cục khác có thể sinh ký tự khác cho cùng phím |
| S8 | Sửa dấu từ trước (⌫ qua dấu cách rồi gõ dấu) chỉ có ở app gõ thẳng được | Chế độ gạch chân không đọc/sửa văn bản đã chốt |
| S9 | Chrome/Electron/VSCode trả `length() = 0` | Phím Việt coi là "không biết" và chỉ dựa vào đọc lại chữ (DECISIONS D11) |
| S10 | Tắt "Kiểm tra âm tiết" làm từ tiếng Anh nhảy chữ lạ trong lúc gõ (`delete` hiện `dêlt`) | Khi chốt vẫn khôi phục đúng; ở app gõ thẳng mỗi lần nhảy là một lần thay chữ. Nên bật kiểm tra âm tiết |
| S7 | ⌘Z hoàn tác theo cách của từng app | Khi gõ trực tiếp, mỗi lần thay chữ là một bước `insertText` của app |

## Môi trường build (máy phát triển hiện tại)

| # | Vấn đề | Chi tiết |
|---|---|---|
| B1 | Không có Xcode → không có XCTest | Test Swift dùng swift-testing qua `scripts/swift_test.sh` (DECISIONS D3) |
| B2 | `macos/project.yml` (XcodeGen) chưa được kiểm chứng | Đường build chính là `scripts/build_bundle.sh` |
| B3 | Cảnh báo link x86_64: `libswiftCompatibilityPacks.a … missing arch 'x86_64'` | Thư viện chỉ phục vụ parameter packs (không dùng). Bản x86_64 đã chạy thử khởi động qua Rosetta, chưa thử trên máy Intel thật |
| B4 | Giao diện Cài đặt chưa được kiểm tra bằng mắt trong môi trường build tự động | Đã build, khởi chạy và giữ tiến trình sống; cần chạy mục "Kiểm tra thêm" trong MANUAL_TEST.md |
| B5 | Không dùng được `@State` trong SwiftUI khi build bằng CLT (SDK 27 biến `@State` thành macro, CLT thiếu plugin `SwiftUIMacros`) | Trạng thái giao diện để trong `SettingsModel` (`@Published`) |
| B6 | Bản ký ad-hoc chỉ dùng trên máy tự build | Phân phối cần Developer ID + notarize (README) |

## Phím Việt Key (app chạy riêng)

| # | Vấn đề | Chi tiết |
|---|---|---|
| K1 | Cần quyền Trợ năng; build lại phải cấp lại | Chữ ký ad-hoc đổi mỗi lần build (DECISIONS D12) |
| K2 | Click / phím điều hướng giữa từ → từ đó không được sửa dấu tiếp | Không đọc tài liệu nên không biết con trỏ đã ở đâu — an toàn hơn đoán |
| K3 | Gõ cực nhanh ở app chậm có thể lệch | Đã thêm độ trễ cho Office/Electron/terminal; app khác báo lỗi thì thêm vào `InjectionMethod.forApp` |
| K4 | Ô có gợi ý lạ (không phải trình duyệt) có thể xoá nhầm phần gợi ý | Trình duyệt đã xử lý bằng ký tự U+202F; app khác chưa |
| K5 | Không chạy khi đang chọn input method khác (kể cả Phím Việt bản IMK) | Chủ ý, tránh gõ chồng — chọn ABC |
| K6 | Ô mật khẩu / Secure Input: không nhận phím | macOS chặn event tap khi Secure Input bật — đúng thiết kế |


# Kiểm thử thủ công

Checklist chạy trên máy thật sau `make install`. Ghi kết quả vào cột **Kết quả**: ✅ đạt · ❌ lỗi (ghi chú cách tái hiện) · ➖ không áp dụng.

## Chuẩn bị

1. `make install` → System Settings → Keyboard → Input Sources → thêm **Phím Việt** (Vietnamese). Chọn Phím Việt.
2. Mặc định: Telex, đặt dấu kiểu mới, "Gạch chân chữ đang gõ" **tắt** (gõ thẳng), kiểm tra âm tiết **bật**, tự khôi phục tiếng Anh **bật**.
3. Mở log trong một Terminal (dùng app khác để gõ thử):
   `log stream --predicate 'subsystem == "com.phimviet.inputmethod.PhimViet"'`
   Sự kiện cần để ý: `trust.proved` / `trust.failed` (app có được gõ trực tiếp không), `direct.abandon` (đã bỏ từ thay vì ghi đè).
4. Ở mỗi app, **hai từ đầu tiên luôn gạch chân** (đang kiểm chứng app); từ thứ ba trở đi mới gõ trực tiếp nếu app đạt.
5. Lặp lại một lượt với **Gạch chân chữ đang gõ = bật** cho các app quan trọng (chế độ gạch chân thuần).

## Các tình huống

| Mã | Tình huống | Cách thử | Kỳ vọng |
|---|---|---|---|
| S1 | Gõ nhanh câu dài | Gõ thật nhanh: `Tooi ddang gox tieengs Vieejt raast nhanh, khoong bij mats chuwx naof.` | Ra đúng `Tôi đang gõ tiếng Việt rất nhanh, không bị mất chữ nào.` — không dính, không nuốt chữ |
| S2 | Gõ dấu cuối từ | `tiengs` → `vietj` → `truongwf` → `nguyenex` | `tiếng việt trường nguyễn` |
| S3 | Backspace giữa từ | Gõ `tieengs`, ⌫ 1 lần, gõ `g`; gõ `vieejt`, ⌫ 2 lần, gõ `eejt` | `tiếng`, `việt`; ⌫ khi chưa gõ gì xoá ký tự bình thường |
| S4 | Click chuột giữa từ | Gõ `vie` (chưa cách), click vào chỗ khác trong văn bản, gõ `es` | Chữ cũ `vie` giữ nguyên; tại chỗ click xuất hiện `é`; không có chữ nào bị ghi đè |
| S5 | Gợi ý tự hoàn thành | Ở ô có gợi ý (thanh URL, Spotlight, ô tìm kiếm), gõ `vieejt` | Ra `việt`, phần gợi ý bôi đen bị thay thế đúng, không thừa/mất ký tự |
| S6 | Chuyển app giữa chừng | Gõ `tieen` (chưa cách), ⌘Tab sang app khác rồi quay lại, gõ tiếp `g` | Không còn chữ gạch chân treo; `g` là đầu từ mới |
| S7 | Ô mật khẩu | Vào ô mật khẩu, gõ `matkhau123` | macOS tự tắt IME trong ô mật khẩu: ký tự gõ ra đúng như phím, không biến đổi |
| S8 | Gõ tắt | Thêm `vn → Việt Nam` trong Cài đặt → Gõ tắt; gõ `vn `, `Vn `, `VN ` | `Việt Nam`, `Việt Nam`, `VIỆT NAM` |
| S9 | ESC | Gõ `vieejt` rồi nhấn ESC | Ra đúng phím thô `vieejt`; ESC không bị gửi tiếp cho app |
| S10 | Tự khôi phục tiếng Anh | Gõ `text with user push class issue ` | Giữ nguyên tiếng Anh |
| S11 | Chuyển V/E | Nhấn-nhả ⌃⇧, gõ `vieejt `, nhấn-nhả ⌃⇧, gõ `vieejt `; đổi sang app khác rồi quay lại | Lần 1 ra `vieejt` (E), lần 2 `việt` (V); mỗi app nhớ chế độ riêng; status item đổi V/E |
| S12 | Hoàn tác ⌘Z | Gõ `tieengs vieejt `, nhấn ⌘Z vài lần | App hoàn tác theo từ/cụm hợp lý; không sinh ký tự lạ, không treo |

## Kết quả theo ứng dụng

### TextEdit

| Mã | Tình huống | Kết quả | Ghi chú |
|---|---|---|---|
| S1 | Gõ nhanh câu dài |  |  |
| S2 | Gõ dấu cuối từ |  |  |
| S3 | Backspace giữa từ |  |  |
| S4 | Click chuột giữa từ |  |  |
| S5 | Gợi ý tự hoàn thành |  |  |
| S6 | Chuyển app giữa chừng |  |  |
| S7 | Ô mật khẩu |  |  |
| S8 | Gõ tắt |  |  |
| S9 | ESC |  |  |
| S10 | Tự khôi phục tiếng Anh |  |  |
| S11 | Chuyển V/E |  |  |
| S12 | Hoàn tác ⌘Z |  |  |

### Notes

| Mã | Tình huống | Kết quả | Ghi chú |
|---|---|---|---|
| S1 | Gõ nhanh câu dài |  |  |
| S2 | Gõ dấu cuối từ |  |  |
| S3 | Backspace giữa từ |  |  |
| S4 | Click chuột giữa từ |  |  |
| S5 | Gợi ý tự hoàn thành |  |  |
| S6 | Chuyển app giữa chừng |  |  |
| S7 | Ô mật khẩu |  |  |
| S8 | Gõ tắt |  |  |
| S9 | ESC |  |  |
| S10 | Tự khôi phục tiếng Anh |  |  |
| S11 | Chuyển V/E |  |  |
| S12 | Hoàn tác ⌘Z |  |  |

### Pages

| Mã | Tình huống | Kết quả | Ghi chú |
|---|---|---|---|
| S1 | Gõ nhanh câu dài |  |  |
| S2 | Gõ dấu cuối từ |  |  |
| S3 | Backspace giữa từ |  |  |
| S4 | Click chuột giữa từ |  |  |
| S5 | Gợi ý tự hoàn thành |  |  |
| S6 | Chuyển app giữa chừng |  |  |
| S7 | Ô mật khẩu |  |  |
| S8 | Gõ tắt |  |  |
| S9 | ESC |  |  |
| S10 | Tự khôi phục tiếng Anh |  |  |
| S11 | Chuyển V/E |  |  |
| S12 | Hoàn tác ⌘Z |  |  |

### Safari — nội dung trang (ô textarea)

| Mã | Tình huống | Kết quả | Ghi chú |
|---|---|---|---|
| S1 | Gõ nhanh câu dài |  |  |
| S2 | Gõ dấu cuối từ |  |  |
| S3 | Backspace giữa từ |  |  |
| S4 | Click chuột giữa từ |  |  |
| S5 | Gợi ý tự hoàn thành |  |  |
| S6 | Chuyển app giữa chừng |  |  |
| S7 | Ô mật khẩu |  |  |
| S8 | Gõ tắt |  |  |
| S9 | ESC |  |  |
| S10 | Tự khôi phục tiếng Anh |  |  |
| S11 | Chuyển V/E |  |  |
| S12 | Hoàn tác ⌘Z |  |  |

### Safari — thanh URL

| Mã | Tình huống | Kết quả | Ghi chú |
|---|---|---|---|
| S1 | Gõ nhanh câu dài |  |  |
| S2 | Gõ dấu cuối từ |  |  |
| S3 | Backspace giữa từ |  |  |
| S4 | Click chuột giữa từ |  |  |
| S5 | Gợi ý tự hoàn thành |  |  |
| S6 | Chuyển app giữa chừng |  |  |
| S7 | Ô mật khẩu |  |  |
| S8 | Gõ tắt |  |  |
| S9 | ESC |  |  |
| S10 | Tự khôi phục tiếng Anh |  |  |
| S11 | Chuyển V/E |  |  |
| S12 | Hoàn tác ⌘Z |  |  |

### Chrome — nội dung trang

| Mã | Tình huống | Kết quả | Ghi chú |
|---|---|---|---|
| S1 | Gõ nhanh câu dài |  |  |
| S2 | Gõ dấu cuối từ |  |  |
| S3 | Backspace giữa từ |  |  |
| S4 | Click chuột giữa từ |  |  |
| S5 | Gợi ý tự hoàn thành |  |  |
| S6 | Chuyển app giữa chừng |  |  |
| S7 | Ô mật khẩu |  |  |
| S8 | Gõ tắt |  |  |
| S9 | ESC |  |  |
| S10 | Tự khôi phục tiếng Anh |  |  |
| S11 | Chuyển V/E |  |  |
| S12 | Hoàn tác ⌘Z |  |  |

### Chrome — thanh URL

| Mã | Tình huống | Kết quả | Ghi chú |
|---|---|---|---|
| S1 | Gõ nhanh câu dài |  |  |
| S2 | Gõ dấu cuối từ |  |  |
| S3 | Backspace giữa từ |  |  |
| S4 | Click chuột giữa từ |  |  |
| S5 | Gợi ý tự hoàn thành |  |  |
| S6 | Chuyển app giữa chừng |  |  |
| S7 | Ô mật khẩu |  |  |
| S8 | Gõ tắt |  |  |
| S9 | ESC |  |  |
| S10 | Tự khôi phục tiếng Anh |  |  |
| S11 | Chuyển V/E |  |  |
| S12 | Hoàn tác ⌘Z |  |  |

### Chrome — Google Docs

> Docs dùng ô nhập ẩn; nếu đọc lại không khớp sẽ tự về chế độ gạch chân.

| Mã | Tình huống | Kết quả | Ghi chú |
|---|---|---|---|
| S1 | Gõ nhanh câu dài |  |  |
| S2 | Gõ dấu cuối từ |  |  |
| S3 | Backspace giữa từ |  |  |
| S4 | Click chuột giữa từ |  |  |
| S5 | Gợi ý tự hoàn thành |  |  |
| S6 | Chuyển app giữa chừng |  |  |
| S7 | Ô mật khẩu |  |  |
| S8 | Gõ tắt |  |  |
| S9 | ESC |  |  |
| S10 | Tự khôi phục tiếng Anh |  |  |
| S11 | Chuyển V/E |  |  |
| S12 | Hoàn tác ⌘Z |  |  |

### Firefox

| Mã | Tình huống | Kết quả | Ghi chú |
|---|---|---|---|
| S1 | Gõ nhanh câu dài |  |  |
| S2 | Gõ dấu cuối từ |  |  |
| S3 | Backspace giữa từ |  |  |
| S4 | Click chuột giữa từ |  |  |
| S5 | Gợi ý tự hoàn thành |  |  |
| S6 | Chuyển app giữa chừng |  |  |
| S7 | Ô mật khẩu |  |  |
| S8 | Gõ tắt |  |  |
| S9 | ESC |  |  |
| S10 | Tự khôi phục tiếng Anh |  |  |
| S11 | Chuyển V/E |  |  |
| S12 | Hoàn tác ⌘Z |  |  |

### Spotlight

> S5 rất quan trọng (gợi ý bôi đen).

| Mã | Tình huống | Kết quả | Ghi chú |
|---|---|---|---|
| S1 | Gõ nhanh câu dài |  |  |
| S2 | Gõ dấu cuối từ |  |  |
| S3 | Backspace giữa từ |  |  |
| S4 | Click chuột giữa từ |  |  |
| S5 | Gợi ý tự hoàn thành |  |  |
| S6 | Chuyển app giữa chừng |  |  |
| S7 | Ô mật khẩu |  |  |
| S8 | Gõ tắt |  |  |
| S9 | ESC |  |  |
| S10 | Tự khôi phục tiếng Anh |  |  |
| S11 | Chuyển V/E |  |  |
| S12 | Hoàn tác ⌘Z |  |  |

### Finder — đổi tên file

| Mã | Tình huống | Kết quả | Ghi chú |
|---|---|---|---|
| S1 | Gõ nhanh câu dài |  |  |
| S2 | Gõ dấu cuối từ |  |  |
| S3 | Backspace giữa từ |  |  |
| S4 | Click chuột giữa từ |  |  |
| S5 | Gợi ý tự hoàn thành |  |  |
| S6 | Chuyển app giữa chừng |  |  |
| S7 | Ô mật khẩu |  |  |
| S8 | Gõ tắt |  |  |
| S9 | ESC |  |  |
| S10 | Tự khôi phục tiếng Anh |  |  |
| S11 | Chuyển V/E |  |  |
| S12 | Hoàn tác ⌘Z |  |  |

### VS Code

> Electron/Monaco: kiểm tra kỹ S4, S5 (gợi ý IntelliSense), S12.

| Mã | Tình huống | Kết quả | Ghi chú |
|---|---|---|---|
| S1 | Gõ nhanh câu dài |  |  |
| S2 | Gõ dấu cuối từ |  |  |
| S3 | Backspace giữa từ |  |  |
| S4 | Click chuột giữa từ |  |  |
| S5 | Gợi ý tự hoàn thành |  |  |
| S6 | Chuyển app giữa chừng |  |  |
| S7 | Ô mật khẩu |  |  |
| S8 | Gõ tắt |  |  |
| S9 | ESC |  |  |
| S10 | Tự khôi phục tiếng Anh |  |  |
| S11 | Chuyển V/E |  |  |
| S12 | Hoàn tác ⌘Z |  |  |

### Cursor

> Từng báo con trỏ sai (1,0) — kỳ vọng tự về chế độ gạch chân, không ghi đè.

| Mã | Tình huống | Kết quả | Ghi chú |
|---|---|---|---|
| S1 | Gõ nhanh câu dài |  |  |
| S2 | Gõ dấu cuối từ |  |  |
| S3 | Backspace giữa từ |  |  |
| S4 | Click chuột giữa từ |  |  |
| S5 | Gợi ý tự hoàn thành |  |  |
| S6 | Chuyển app giữa chừng |  |  |
| S7 | Ô mật khẩu |  |  |
| S8 | Gõ tắt |  |  |
| S9 | ESC |  |  |
| S10 | Tự khôi phục tiếng Anh |  |  |
| S11 | Chuyển V/E |  |  |
| S12 | Hoàn tác ⌘Z |  |  |

### Xcode

| Mã | Tình huống | Kết quả | Ghi chú |
|---|---|---|---|
| S1 | Gõ nhanh câu dài |  |  |
| S2 | Gõ dấu cuối từ |  |  |
| S3 | Backspace giữa từ |  |  |
| S4 | Click chuột giữa từ |  |  |
| S5 | Gợi ý tự hoàn thành |  |  |
| S6 | Chuyển app giữa chừng |  |  |
| S7 | Ô mật khẩu |  |  |
| S8 | Gõ tắt |  |  |
| S9 | ESC |  |  |
| S10 | Tự khôi phục tiếng Anh |  |  |
| S11 | Chuyển V/E |  |  |
| S12 | Hoàn tác ⌘Z |  |  |

### Terminal

> Terminal thường không cho đọc tài liệu → luôn dùng chế độ gạch chân (đúng thiết kế).

| Mã | Tình huống | Kết quả | Ghi chú |
|---|---|---|---|
| S1 | Gõ nhanh câu dài |  |  |
| S2 | Gõ dấu cuối từ |  |  |
| S3 | Backspace giữa từ |  |  |
| S4 | Click chuột giữa từ |  |  |
| S5 | Gợi ý tự hoàn thành |  |  |
| S6 | Chuyển app giữa chừng |  |  |
| S7 | Ô mật khẩu |  |  |
| S8 | Gõ tắt |  |  |
| S9 | ESC |  |  |
| S10 | Tự khôi phục tiếng Anh |  |  |
| S11 | Chuyển V/E |  |  |
| S12 | Hoàn tác ⌘Z |  |  |

### iTerm2

> Có thể luôn dùng chế độ gạch chân.

| Mã | Tình huống | Kết quả | Ghi chú |
|---|---|---|---|
| S1 | Gõ nhanh câu dài |  |  |
| S2 | Gõ dấu cuối từ |  |  |
| S3 | Backspace giữa từ |  |  |
| S4 | Click chuột giữa từ |  |  |
| S5 | Gợi ý tự hoàn thành |  |  |
| S6 | Chuyển app giữa chừng |  |  |
| S7 | Ô mật khẩu |  |  |
| S8 | Gõ tắt |  |  |
| S9 | ESC |  |  |
| S10 | Tự khôi phục tiếng Anh |  |  |
| S11 | Chuyển V/E |  |  |
| S12 | Hoàn tác ⌘Z |  |  |

### Claude Code trong terminal

> Như terminal chứa nó; chú ý ô nhập nhiều dòng.

| Mã | Tình huống | Kết quả | Ghi chú |
|---|---|---|---|
| S1 | Gõ nhanh câu dài |  |  |
| S2 | Gõ dấu cuối từ |  |  |
| S3 | Backspace giữa từ |  |  |
| S4 | Click chuột giữa từ |  |  |
| S5 | Gợi ý tự hoàn thành |  |  |
| S6 | Chuyển app giữa chừng |  |  |
| S7 | Ô mật khẩu |  |  |
| S8 | Gõ tắt |  |  |
| S9 | ESC |  |  |
| S10 | Tự khôi phục tiếng Anh |  |  |
| S11 | Chuyển V/E |  |  |
| S12 | Hoàn tác ⌘Z |  |  |

### Slack

| Mã | Tình huống | Kết quả | Ghi chú |
|---|---|---|---|
| S1 | Gõ nhanh câu dài |  |  |
| S2 | Gõ dấu cuối từ |  |  |
| S3 | Backspace giữa từ |  |  |
| S4 | Click chuột giữa từ |  |  |
| S5 | Gợi ý tự hoàn thành |  |  |
| S6 | Chuyển app giữa chừng |  |  |
| S7 | Ô mật khẩu |  |  |
| S8 | Gõ tắt |  |  |
| S9 | ESC |  |  |
| S10 | Tự khôi phục tiếng Anh |  |  |
| S11 | Chuyển V/E |  |  |
| S12 | Hoàn tác ⌘Z |  |  |

### Discord

| Mã | Tình huống | Kết quả | Ghi chú |
|---|---|---|---|
| S1 | Gõ nhanh câu dài |  |  |
| S2 | Gõ dấu cuối từ |  |  |
| S3 | Backspace giữa từ |  |  |
| S4 | Click chuột giữa từ |  |  |
| S5 | Gợi ý tự hoàn thành |  |  |
| S6 | Chuyển app giữa chừng |  |  |
| S7 | Ô mật khẩu |  |  |
| S8 | Gõ tắt |  |  |
| S9 | ESC |  |  |
| S10 | Tự khôi phục tiếng Anh |  |  |
| S11 | Chuyển V/E |  |  |
| S12 | Hoàn tác ⌘Z |  |  |

### Messages

| Mã | Tình huống | Kết quả | Ghi chú |
|---|---|---|---|
| S1 | Gõ nhanh câu dài |  |  |
| S2 | Gõ dấu cuối từ |  |  |
| S3 | Backspace giữa từ |  |  |
| S4 | Click chuột giữa từ |  |  |
| S5 | Gợi ý tự hoàn thành |  |  |
| S6 | Chuyển app giữa chừng |  |  |
| S7 | Ô mật khẩu |  |  |
| S8 | Gõ tắt |  |  |
| S9 | ESC |  |  |
| S10 | Tự khôi phục tiếng Anh |  |  |
| S11 | Chuyển V/E |  |  |
| S12 | Hoàn tác ⌘Z |  |  |

### Zalo

| Mã | Tình huống | Kết quả | Ghi chú |
|---|---|---|---|
| S1 | Gõ nhanh câu dài |  |  |
| S2 | Gõ dấu cuối từ |  |  |
| S3 | Backspace giữa từ |  |  |
| S4 | Click chuột giữa từ |  |  |
| S5 | Gợi ý tự hoàn thành |  |  |
| S6 | Chuyển app giữa chừng |  |  |
| S7 | Ô mật khẩu |  |  |
| S8 | Gõ tắt |  |  |
| S9 | ESC |  |  |
| S10 | Tự khôi phục tiếng Anh |  |  |
| S11 | Chuyển V/E |  |  |
| S12 | Hoàn tác ⌘Z |  |  |

### Telegram

| Mã | Tình huống | Kết quả | Ghi chú |
|---|---|---|---|
| S1 | Gõ nhanh câu dài |  |  |
| S2 | Gõ dấu cuối từ |  |  |
| S3 | Backspace giữa từ |  |  |
| S4 | Click chuột giữa từ |  |  |
| S5 | Gợi ý tự hoàn thành |  |  |
| S6 | Chuyển app giữa chừng |  |  |
| S7 | Ô mật khẩu |  |  |
| S8 | Gõ tắt |  |  |
| S9 | ESC |  |  |
| S10 | Tự khôi phục tiếng Anh |  |  |
| S11 | Chuyển V/E |  |  |
| S12 | Hoàn tác ⌘Z |  |  |

### Excel

> Kiểm tra cả khi gõ trong ô (có gợi ý tự hoàn thành) và thanh công thức.

| Mã | Tình huống | Kết quả | Ghi chú |
|---|---|---|---|
| S1 | Gõ nhanh câu dài |  |  |
| S2 | Gõ dấu cuối từ |  |  |
| S3 | Backspace giữa từ |  |  |
| S4 | Click chuột giữa từ |  |  |
| S5 | Gợi ý tự hoàn thành |  |  |
| S6 | Chuyển app giữa chừng |  |  |
| S7 | Ô mật khẩu |  |  |
| S8 | Gõ tắt |  |  |
| S9 | ESC |  |  |
| S10 | Tự khôi phục tiếng Anh |  |  |
| S11 | Chuyển V/E |  |  |
| S12 | Hoàn tác ⌘Z |  |  |

### Word

| Mã | Tình huống | Kết quả | Ghi chú |
|---|---|---|---|
| S1 | Gõ nhanh câu dài |  |  |
| S2 | Gõ dấu cuối từ |  |  |
| S3 | Backspace giữa từ |  |  |
| S4 | Click chuột giữa từ |  |  |
| S5 | Gợi ý tự hoàn thành |  |  |
| S6 | Chuyển app giữa chừng |  |  |
| S7 | Ô mật khẩu |  |  |
| S8 | Gõ tắt |  |  |
| S9 | ESC |  |  |
| S10 | Tự khôi phục tiếng Anh |  |  |
| S11 | Chuyển V/E |  |  |
| S12 | Hoàn tác ⌘Z |  |  |

### Notion

| Mã | Tình huống | Kết quả | Ghi chú |
|---|---|---|---|
| S1 | Gõ nhanh câu dài |  |  |
| S2 | Gõ dấu cuối từ |  |  |
| S3 | Backspace giữa từ |  |  |
| S4 | Click chuột giữa từ |  |  |
| S5 | Gợi ý tự hoàn thành |  |  |
| S6 | Chuyển app giữa chừng |  |  |
| S7 | Ô mật khẩu |  |  |
| S8 | Gõ tắt |  |  |
| S9 | ESC |  |  |
| S10 | Tự khôi phục tiếng Anh |  |  |
| S11 | Chuyển V/E |  |  |
| S12 | Hoàn tác ⌘Z |  |  |

## Kiểm tra thêm (một lần)

| Hạng mục | Cách thử | Kết quả |
|---|---|---|
| Menu nhập liệu | Mở menu input source: đổi Telex/VNI/Simple Telex, kiểu đặt dấu, 3 công tắc — áp dụng ngay không cần khởi động lại |  |
| Cài đặt | Menu → Cài đặt…: đủ 5 tab, Dark Mode hiển thị đúng, đổi tuỳ chọn áp dụng ngay |  |
| Gõ tắt nhập/xuất | Xuất JSON, xoá vài dòng, nhập lại file vừa xuất |  |
| Ứng dụng luôn E/V | Thêm Terminal vào "Luôn gõ tiếng Anh" → vào Terminal tự là E |  |
| Status item | Tắt/bật "Hiện V/E trên thanh menu"; bấm vào biểu tượng đổi V/E |  |
| VNI | Đổi sang VNI, gõ `Vie65t Nam` → `Việt Nam` |  |
| Kiểu cũ | Đổi đặt dấu kiểu cũ, gõ `hoaf thuyr` → `hòa thủy` |  |
| Gỡ cài đặt | `make uninstall` → Phím Việt biến mất khỏi danh sách (có thể cần đăng xuất) |  |

## Phím Việt Key (app chạy riêng)

Chuẩn bị: `make install-key` → bật quyền Trợ năng → chọn **ABC** trên thanh menu → biểu tượng hiện `V`.

| Mã | Tình huống | Cách thử | Kỳ vọng | Kết quả |
|---|---|---|---|---|
| K1 | Word | Gõ `hoom nay laf thuws hai, vieejt nam.` | Đúng chữ, **không gạch chân** | |
| K2 | Chrome — nội dung trang | Ô soạn Gmail / Google Docs, gõ câu K1 | Như K1 | |
| K3 | Chrome — thanh địa chỉ | Gõ `vieejt` khi Chrome gợi ý `vietnamnet.vn` | Ra `việt`, gợi ý bị huỷ đúng, không mất/thừa chữ | |
| K4 | Sửa dấu từ trước | `may ` ⌫ `as` | `mấy` | |
| K5 | Tiếng Anh | `delete select release data ` | Giữ nguyên | |
| K6 | Đổi nguồn nhập | Chọn Phím Việt (IMK) trên thanh menu | Biểu tượng Key thành `V–`, không gõ chồng | |
| K7 | ⌃⇧ | Nhấn-nhả ⌃⇧ | `V` ⇄ `E`, nhớ theo app | |
| K8 | Gõ nhanh | Gõ nhanh câu S1 trong TextEdit, VS Code, Slack | Không mất/dính chữ | |


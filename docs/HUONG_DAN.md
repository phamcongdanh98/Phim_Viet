# Hướng dẫn cài đặt & sử dụng Phím Việt

Bộ gõ tiếng Việt cho macOS 13 trở lên (Apple Silicon và Intel). Tác giả: **Danh Phạm - 0356719463**.

## 1. Cài đặt trên máy mới

1. Tải file **`PhimViet-<phiên bản>.dmg`** ở mục [Releases](https://github.com/phamcongdanh98/Phim_Viet/releases)
   (hoặc nhận file từ người khác), bấm đúp để mở.
2. Bấm đúp **Cài đặt Phím Việt.command**. Một cửa sổ Terminal hiện ra, cài xong sẽ hỏi có mở Phím Việt Key không.
3. Nếu macOS báo *"không thể mở vì từ nhà phát triển không xác định"* (bản này chưa ký bằng chứng chỉ trả phí của
   Apple), dùng **một** trong hai cách:
   - Mở **Terminal**, kéo file *Cài đặt Phím Việt.command* vào cửa sổ Terminal, nhấn **Enter**; hoặc
   - **System Settings → Privacy & Security** → kéo xuống → bấm **Open Anyway** → bấm đúp lại file cài đặt.

Không cần mật khẩu quản trị, không cần Xcode hay Rust. Bộ gõ được cài vào `~/Library/Input Methods`.

## 2. Chọn cách gõ (chỉ dùng MỘT trong hai)

| | **Phím Việt Key** — khuyên dùng | **Phím Việt** |
|---|---|---|
| Gạch chân chữ đang gõ | **Không**, ở mọi app (Word, Chrome, Zalo…) | Có ở một số app (Word, vài ô Chrome) |
| Cần cấp quyền | Trợ năng (Accessibility) | Không |
| Chọn trên thanh menu | Bàn phím **ABC** | **Phím Việt** |

### Dùng Phím Việt Key

1. Mở app: trả lời **c** khi bộ cài hỏi, hoặc dán vào Terminal:
   `open ~/Library/Input\ Methods/PhimViet.app/Contents/Helpers/PhimVietKey.app`
2. Cấp quyền: **System Settings → Privacy & Security → Accessibility** → bật **Phím Việt Key**.
   Nếu không thấy trong danh sách: bấm **+**, nhấn ⌘⇧G, dán
   `~/Library/Input Methods/PhimViet.app/Contents/Helpers/`, chọn **PhimVietKey.app**.
3. Chọn bàn phím **ABC** trên thanh menu.
4. Biểu tượng **V** (đang gõ Việt) / **E** (đang gõ Anh) hiện trên thanh menu. **V!** = chưa có quyền.
   Phím Việt Key tự nghỉ và ẩn biểu tượng khi bạn chọn bộ gõ khác (kể cả Phím Việt) — không bao giờ gõ chồng.
5. Muốn tự chạy khi bật máy: menu **V** → **Mở cùng máy**.

### Dùng Phím Việt (không cần quyền)

1. **System Settings → Keyboard → Text Input → Input Sources: Edit…** → **+** → **Vietnamese** →
   **Phím Việt** → **Thêm**.
2. Chọn **Phím Việt** trên thanh menu.
3. Ở mỗi app, 2 từ đầu tiên có gạch chân trong lúc Phím Việt kiểm tra app; các từ sau gõ thẳng nếu app hỗ trợ.

> Nên bỏ **Vietnamese – Telex/VNI của Apple** khỏi danh sách nguồn nhập (chọn nó → nút **−**) để khỏi chuyển nhầm.

## 3. Cách gõ

### Telex (mặc định)

| Phím | Kết quả | Ví dụ |
|---|---|---|
| `s` `f` `r` `x` `j` | sắc · huyền · hỏi · ngã · nặng | `toans` → toán |
| `z` | xoá dấu | `toansz` → toan |
| `aa` `ee` `oo` | â · ê · ô | `vieet` → viêt |
| `aw` `ow` `uw`, `w` | ă · ơ · ư, ư | `tuw` → tư, `nhw` → như |
| `dd` | đ | `ddi` → đi |
| `uow` | ươ | `nguowif` → người |

- Gõ dấu ở đâu cũng được: `tiengse`, `tieengs` đều ra **tiếng**.
- Muốn `xoong`, `boong`: gõ `xooong`.

### VNI

`1` sắc · `2` huyền · `3` hỏi · `4` ngã · `5` nặng · `0` xoá dấu · `6` mũ (â ê ô) · `7` móc (ơ ư) · `8` trăng (ă) · `9` đ.
Ví dụ: `Vie65t Nam` → Việt Nam, `d9uo7ng2` → đường.

### Phím & mẹo hay dùng

| Việc | Cách |
|---|---|
| Chuyển Việt ⇄ Anh | Nhấn rồi nhả **⌃ Control + ⇧ Shift**. Mỗi app nhớ chế độ riêng |
| Lấy lại đúng phím đã gõ | **ESC** khi đang gõ dở: `vieejt` → ESC → `vieejt` |
| Sửa dấu từ vừa gõ xong | ⌫ xoá dấu cách rồi gõ dấu: `may␣` ⌫ `as` → **mấy** |
| Bỏ dấu bằng gõ đôi | `ass` → as, `aaa` → aa, `tesst` → **test**, `thiss` → **this** |
| Từ tiếng Anh | Tự giữ nguyên khi gõ xong: `data`, `delete`, `pass`, `issue`, `www.google.com` |
| Từ tiếng Anh trùng chữ Việt | `test` → tét, `this` → thí: gõ đôi phím dấu (`tesst`, `thiss`) hoặc nhấn ESC |
| Đổi kiểu gõ, kiểu đặt dấu (hoà/hòa) | Menu **V** trên thanh menu |
| Gõ tắt, danh sách app luôn Việt/Anh | Menu **V** → **Cài đặt…** |

## 4. Lưu ý

- **Mật khẩu trong Terminal** (`sudo`, `ssh`): Terminal không bảo vệ ô mật khẩu, nên ở chế độ Việt mật khẩu có thể bị
  thêm dấu. Thêm Terminal vào **Cài đặt → Ứng dụng → Luôn gõ tiếng Anh**, hoặc bật Terminal → *Secure Keyboard Entry*.
- Ô mật khẩu thường (web, app) được macOS bảo vệ: bộ gõ không nhận phím, gõ ra đúng như bàn phím.
- Riêng tư: không kết nối mạng, không thu thập dữ liệu, không ghi lại nội dung bạn gõ.

## 5. Xử lý sự cố

| Hiện tượng | Cách xử lý |
|---|---|
| Biểu tượng **V!** / Phím Việt Key không đổi chữ | Chưa có quyền Trợ năng: xem mục 2 bước 2. Xoá mục cũ bằng **−** rồi thêm lại |
| Gõ không ra dấu dù đã cấp quyền | Kiểm tra đang chọn **ABC** trên thanh menu và biểu tượng là **V** (không phải E) |
| Không thấy **Phím Việt** trong danh sách nguồn nhập | Đóng/mở lại cửa sổ cài đặt; vẫn không thấy thì đăng xuất rồi đăng nhập lại |
| Thấy hai chữ **V** trên thanh menu | V trong ô vuông là menu nguồn nhập của macOS; V chữ trơn là biểu tượng Việt/Anh của Phím Việt. Tắt bớt một cái trong **Cài đặt…** của Phím Việt, hoặc tắt *Hiển thị menu Đầu vào* trong cài đặt Bàn phím |
| Gõ lỗi ở một app cụ thể | Báo lỗi kèm tên app tại [Issues](https://github.com/phamcongdanh98/Phim_Viet/issues) |

## 6. Cập nhật & gỡ cài đặt

- **Cập nhật:** mở file `.dmg` mới, chạy lại *Cài đặt Phím Việt.command*. Bản ký cùng chứng chỉ giữ nguyên quyền Trợ
  năng; nếu Phím Việt Key hiện **V!** sau khi cập nhật thì cấp lại quyền như mục 2.
- **Gỡ:** chạy *Gỡ cài đặt Phím Việt.command* trong file `.dmg` (cài đặt của bạn được giữ lại).

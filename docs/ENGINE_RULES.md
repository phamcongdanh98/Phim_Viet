# Quy tắc engine Phím Việt

Tài liệu này là **đặc tả** cho lõi Rust (`core/`). Mỗi quy tắc có test tương ứng
(`core/tests/hard_cases.rs`, `core/tests/syllables.rs`, …). Khi đổi hành vi: sửa tài liệu này trước.

## 1. Mô hình: tính lại từ phím thô

- Mỗi từ đang gõ = dãy **phím thô** (`raw`) đúng như người dùng gõ (giữ hoa/thường).
- Mỗi phím: thêm vào `raw`, rồi `render(raw, config)` tính lại **toàn bộ** chữ hiển thị.
  `render` là hàm thuần, tất định: cùng `raw` + `config` → cùng kết quả.
- Bên trong, `render` duyệt `raw` từ đầu, áp từng phím vào một trạng thái tạm
  (danh sách chữ cái có dấu phụ + một thanh điệu cho cả âm tiết). Thanh điệu là
  **thuộc tính của âm tiết**, vị trí đặt thanh chỉ được tính khi xuất chuỗi.
- Đầu ra luôn là Unicode dựng sẵn (NFC), không bao giờ có dấu kết hợp U+0300–U+036F.

## 2. Bảng phím

### Telex
| Phím | Tác dụng |
|---|---|
| `s f r x j` | thanh sắc, huyền, hỏi, ngã, nặng |
| `z` | xoá thanh (nếu chưa có thanh → chữ `z` thường) |
| `aa ee oo` | `â ê ô` (phím thứ hai có thể gõ sau phụ âm cuối: `tiengse`) |
| `aw ow uw` | `ă ơ ư`; `uo`+`w` → `ươ` |
| `dd` | `đ` (phím `d` thứ hai có thể gõ sau vần: `did` → `đi`) |
| `w` đứng riêng | `ư` (tuỳ chọn `w_as_u`, mặc định bật) |
| `[` `]` | `ơ` `ư` (tuỳ chọn `brackets`, mặc định tắt) |

### Simple Telex
Như Telex nhưng `w` đứng riêng là chữ `w` thường và không có `[ ]`.

### VNI
| Phím | Tác dụng |
|---|---|
| `1 2 3 4 5` | sắc, huyền, hỏi, ngã, nặng |
| `0` | xoá thanh |
| `6` | mũ: `â ê ô` |
| `7` | móc: `ơ ư`; `uo7` → `ươ` |
| `8` | trăng: `ă` |
| `9` | `đ` |

Chữ số chỉ là phím VNI khi đang có từ dở; gõ chữ số khi chưa có từ → đưa thẳng cho ứng dụng.

## 3. Phân tích âm tiết

Âm tiết = **phụ âm đầu** + **vần** (cụm nguyên âm + phụ âm cuối) + **thanh**.

### 3.1 Phụ âm đầu hợp lệ
`b c ch d đ g gh gi h k kh l m n ng ngh nh p ph qu r s t th tr v x` và rỗng.

- `qu`: `q` luôn đi với `u`; `u` thuộc phụ âm đầu (`quá` → thanh trên `a`).
- `gi`: nếu sau `gi` còn nguyên âm → `gi` là phụ âm đầu (`già`, `giữa`, `giếng`).
  Nếu sau `gi` không còn nguyên âm → `g` + vần bắt đầu bằng `i` (`gì`, `gìn`).

### 3.2 Vần hợp lệ (không kể thanh)
```
a ac ach ai am an ang anh ao ap at au ay
ăc ăm ăn ăng ăp ăt
âc âm ân âng âp ât âu ây
e ec em en eng eo ep et
ê êch êm ên ênh êng êp êt êu
i ia ich im in inh ip it iu
iêc iêm iên iêng iêp iêt iêu
yêm yên yêng yêt yêu
o oc oi om on ong op ot
oa oac oach oai oam oan oang oanh oap oat oay
oăc oăm oăn oăng oăt
oe oen oeo oet
ooc oong
ô ôc ôi ôm ôn ông ôp ôt
ơ ơi ơm ơn ơp ơt
u ua uc ui um un ung up ut
uân uâng uât uây
uê uêch uênh
uôc uôi uôm uôn uông uôt
uơ
uy uya uych uynh uyp uyt uyu uyên uyêt uyêch
ư ưa ưc ưi ưm ưng ưt ưu
ươc ươi ươm ươn ương ươp ươt ươu
y
```

### 3.3 Ràng buộc chính tả (phụ âm đầu ↔ vần)
| Phụ âm đầu | Ràng buộc |
|---|---|
| `k` | vần bắt đầu bằng `i e ê y` |
| `gh`, `ngh` | vần bắt đầu bằng `i e ê` |
| `c`, `ng` | vần **không** bắt đầu bằng `i e ê y` |
| `g` | vần không bắt đầu bằng `e ê y`; nếu bắt đầu bằng `i` thì chỉ `i in im ip it ich inh` (tức `gì gìn …`) |
| `gi` | vần không bắt đầu bằng `i y`, không là vần có âm đệm (`oa oă oe uâ uê uy uơ`) |
| `qu` | vần sau `qu` (gọi R) hợp lệ nếu `o`+R ∈ {`oa…`, `oă…`, `oe…`} hoặc `u`+R ∈ {`uâ…`, `uê…`, `uy…`, `uơ`}, hoặc R ∈ {`ên`, `êt`, `ôc`, `i`, `in`, `it`} (bảng `QU_RHYMES`) |
| rỗng | vần không bắt đầu bằng `iê` (dùng `yê`) |
| khác rỗng | vần không bắt đầu bằng `yê` (dùng `iê`) — `uyê` vẫn hợp lệ |
| `uơ` | chỉ sau `h th kh` (`huơ`, `thuở`) |

### 3.4 Ràng buộc thanh
Vần kết thúc bằng `c ch p t` chỉ đi với thanh **sắc** hoặc **nặng**.

### 3.5 Hai mức hợp lệ
- **Hợp lệ đầy đủ** (dùng khi chốt từ): phụ âm đầu ∈ 3.1, vần ∈ 3.2, thoả 3.3 và 3.4.
- **Hợp lệ tiền tố** (dùng khi đang gõ): phụ âm đầu là tiền tố của một phụ âm đầu hợp lệ
  (nếu chưa có nguyên âm); vần hiện tại là **tiền tố yếu** của một vần hợp lệ thoả 3.3:
  cùng chữ gốc từng vị trí, dấu phụ hoặc trùng hoặc chưa có (vì phím mũ/móc có thể gõ sau).
  Không xét 3.4 (thanh còn đổi được).

## 4. Áp phím (trong `render`)

1. **Chữ thường** (phụ âm, nguyên âm không phải phím biến đổi): thêm vào cuối.
2. **Phím thanh**: nếu từ có nguyên âm → đặt thanh của âm tiết (thay thanh cũ).
   Nếu chưa có nguyên âm → là chữ thường.
3. **Phím mũ** (`a e o` Telex, `6` VNI): tìm trong cụm nguyên âm chữ gốc tương ứng
   (VNI: `a e o`). Thứ tự quyết định:
   1. ứng viên (từ phải sang trái) cho kết quả hợp lệ tiền tố → đặt mũ;
   2. nếu thêm phím như chữ thường cho kết quả hợp lệ tiền tố → thêm chữ (`boeo` → `boeo`, không thành `bôe`);
   3. nếu đã có mũ → huỷ (§4.6);
   4. còn ứng viên → đặt mũ cho ứng viên đầu; không có → chữ thường (VNI: ký tự `6`).
4. **Phím móc/trăng** (`w` Telex; `7`, `8` VNI): ứng viên theo thứ tự
   `uo→ươ`, `o→ơ`, `u→ư`, `a→ă` (VNI `7` bỏ `a→ă`; `8` chỉ `a→ă`); chọn ứng viên đầu tiên
   hợp lệ tiền tố, nếu không có thì ứng viên đầu tiên. Không ứng viên → Telex `w`: chèn `ư`
   (nếu bật `w_as_u`) hoặc chữ `w`.
5. **`đ`** (`d` Telex, `9` VNI): nếu chữ cái đầu từ là `d` → `đ` (gõ tự do: `dd`, `did`, `dand`).
6. **Gõ đúp để huỷ**: nếu phím biến đổi gặp lại đúng trạng thái nó đã tạo
   (`â`+`a`, thanh sắc + `s`, `đ`+`d`, `ư`+`w`, VNI `á`+`1`…) → bỏ biến đổi đó, thêm phím
   như **chữ thường**, và phím đó bị vô hiệu (chỉ là chữ thường) cho tới hết từ.
   `aaa→aa`, `ass→as`, `ddd→dd`, `ww→w`, `a11→a1`.
7. **`uơ`/`ươ`** (hàm `normalize`):
   - `w`/`7` áp lên cặp `uo` thì móc của `u` là "ngầm định". Nếu sau `ơ` không còn chữ nào → hiển thị `uơ`
     (`thuowr` → `thuở`, `huow` → `huơ`); có chữ theo sau → `ươ` (`thuowng` → `thương`).
   - `ư` + `o` + chữ theo sau → `ươ` (`dduwocj` → `được`, `truwongf` → `trường`).
   - Móc gõ tường minh ở cuối từ (`thuwowr`) hiển thị `thưở`, khi chốt sửa thành `thuở` (§7).

## 5. Đặt thanh

1. Cụm nguyên âm có chữ mang dấu phụ (`â ă ê ô ơ ư`) → đặt ở chữ mang dấu phụ **cuối cùng**
   (`ươ`→`ơ`, `uô`→`ô`, `iê/yê`→`ê`, `ưa`→`ư`, `ưu`→`ư`).
2. Có phụ âm cuối → nguyên âm cuối của cụm (`toán`, `hoàng`, `quýt`, `xoòng`).
3. Không phụ âm cuối:
   - 3 nguyên âm → nguyên âm giữa (`khoái`, `ngoáy`, `khuỷu`, `khuýa`).
   - `oa oe uy`: **kiểu mới** (mặc định) → nguyên âm sau (`hoà khoẻ thuỷ`);
     **kiểu cũ** → nguyên âm đầu (`hòa khỏe thủy`).
   - `oo` → chữ o thứ hai (`boóng`).
   - 2 nguyên âm khác → nguyên âm đầu (`hài mía mùa`).
   - 1 nguyên âm → nguyên âm đó.
4. `gi`, `qu` không tính vào cụm nguyên âm (`già`, `quá`, `quyển`); `gì` thì `i` là nguyên âm.

## 6. Hiển thị khi đang gõ

Gọi `T` = kết quả áp phím. Hiển thị:
- `T` nếu tắt kiểm tra âm tiết, hoặc `T` hợp lệ tiền tố, hoặc từ đang ở **đuôi huỷ tường minh**;
- ngược lại hiển thị **phím thô** (`wit`, `class`, `issu`).

**Đuôi huỷ tường minh**: phím vừa huỷ một biến đổi mà người dùng *có chủ ý* — trước phím đó
`T` là chữ Việt hợp lệ tiền tố, **hoặc** (khi tắt kiểm tra âm tiết) phím huỷ gõ lặp ngay sau phím
vừa biến đổi (`aaa`, `ass`) — mọi phím sau đó đều là cùng phím ấy
(`ass`, `asss`, `aaa`, `ww`), **và** `T` sau huỷ là chữ ASCII thuần.
Gõ phím khác → hết đuôi huỷ (`issue` → hiển thị thô). `express` → `êps` không phải ASCII
→ không công nhận → khôi phục `express`. Tắt kiểm tra âm tiết: `delete` hiện `dêlt` rồi `e` huỷ dấu mũ,
nhưng `dêlt` không hợp lệ và `e` không gõ lặp ngay → không công nhận → chốt `delete` (không phải `delte`).

**Gõ đôi để huỷ dấu giữa từ** (`tesst` → `test`): phím huỷ phải gõ **liền** ngay sau phím vừa biến đổi
(`ass`, `aaa`; `basis` có hai `s` cách nhau → không phải huỷ) và chữ sau huỷ là ASCII thuần. Khi đó:
lúc đang gõ hiện chữ đã huỷ (`tess` → `tes`), trừ khi đã gõ thêm chữ mà chữ sau huỷ không còn là âm tiết Việt
dở dang và phím thô là đầu một từ tiếng Anh có sẵn cặp chữ đôi (`issu` → hiện `issu`). Khi chốt: xem §7.

**Từ không có nguyên âm** (`đ`, `đc`, `đt` — viết tắt thường gặp): luôn hiển thị `T`,
không bị khôi phục khi chốt (`dd` → `đ`; muốn `dd` gõ `ddd`).

## 7. Chốt từ (space, dấu câu, enter, tab; click/đổi ô)

> **Từ có gõ đôi để huỷ dấu** (§6) được quyết định trước mọi bước khác (sau gõ tắt): nếu phím thô là từ tiếng Anh
> trong danh sách `core/data/en_double.txt` (kể cả đuôi `s/es/ed/ing/er…`) và bật tự khôi phục → phím thô
> (`pass`, `issue`, `classes`, `daddy`); ngược lại → chữ đã huỷ (`tesst` → `test`, `thiss` → `this`).
> Danh sách: từ 4–14 chữ chứa `ss ff rr xx jj dd aa ee oo ww` trong `/usr/share/dict/words`
> (Webster 1934, hết bản quyền) + `off err add odd`; sinh lại bằng `scripts/gen_en_double.sh`.

Thứ tự:
1. **Gõ tắt** (chỉ khi chốt bằng phím và bật gõ tắt): nếu `raw` (không phân biệt hoa thường)
   hoặc chữ hiển thị khớp một từ tắt → thay bằng cụm, giữ kiểu hoa:
   toàn thường → nguyên văn; chữ đầu hoa → viết hoa chữ đầu cụm; toàn hoa (≥2 chữ) → viết hoa cả cụm.
2. **Tự khôi phục tiếng Anh** (bật mặc định): nếu `T` không hợp lệ đầy đủ và không ở đuôi huỷ
   tường minh → trả **phím thô** (`text`, `with`, `expect`, `user`, `push`, `wow`).
   Từ vừa hợp lệ tiếng Việt vừa là tiếng Anh (`mix→mĩ`, `box→bõ`, `test→tét`) giữ tiếng Việt.
3. Ngoại lệ: `ươ` cuối từ có móc tường minh sau `h th kh` → chốt thành `uơ` (`thuwowr` → `thuở`).
4. Ngược lại giữ chữ đang hiển thị.

## 8. Backspace

Xoá **1 ký tự hiển thị** cuối. Raw mới được dựng lại:
1. Raw chuẩn từ chuỗi còn lại (Telex: chữ gốc + phím dấu phụ ngay sau, thanh ở cuối;
   VNI tương tự với số) — dùng nếu `render(raw chuẩn) == chuỗi còn lại`.
2. Nếu không, thử dùng chính các ký tự còn lại làm phím.
3. Nếu vẫn không khớp → từ chuyển sang **đóng băng**: phần còn lại giữ nguyên văn,
   phím gõ thêm được nối thẳng, không biến đổi.

`tiếng` ⌫ → `tiến` (raw `tieens`), gõ `g` → `tiếng`.

## 9. ESC
Đang có từ dở → thay bằng đúng phím thô đã gõ, kết thúc từ, phím ESC bị nuốt.
Sau Backspace, "phím thô" là raw chuẩn dựng lại ở §8 (DECISIONS D7).

## 10. Hoa/thường
Mỗi chữ cái giữ hoa/thường của phím tạo ra nó; phím dấu/thanh không đổi hoa thường
(`VIEETJ→VIỆT`, `Dd→Đ`, `DD→Đ`, `TieengS→Tiếng`). Cờ Caps Lock: chữ cái được viết hoa.

## 11. Ranh giới từ
Mọi ký tự không phải phím của kiểu gõ (chữ số trong Telex, dấu câu, ký hiệu, khoảng trắng,
ký tự ngoài ASCII) → chốt từ hiện tại, ký tự được đưa cho ứng dụng.

//! Chữ cái tiếng Việt: dấu phụ (mũ/trăng/móc/gạch), thanh điệu, dựng/tách ký tự NFC.

/// Dấu phụ gắn vào chữ cái (không phải thanh điệu).
#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
pub enum Mark {
    #[default]
    None,
    /// â ê ô
    Circumflex,
    /// ă
    Breve,
    /// ơ ư
    Horn,
    /// đ
    Stroke,
}

/// Thanh điệu của âm tiết.
#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
pub enum Tone {
    #[default]
    None,
    /// sắc
    Acute,
    /// huyền
    Grave,
    /// hỏi
    Hook,
    /// ngã
    Tilde,
    /// nặng
    Dot,
}

impl Tone {
    pub(crate) fn index(self) -> usize {
        match self {
            Tone::None => 0,
            Tone::Acute => 1,
            Tone::Grave => 2,
            Tone::Hook => 3,
            Tone::Tilde => 4,
            Tone::Dot => 5,
        }
    }

    pub(crate) fn from_index(i: usize) -> Tone {
        match i {
            1 => Tone::Acute,
            2 => Tone::Grave,
            3 => Tone::Hook,
            4 => Tone::Tilde,
            5 => Tone::Dot,
            _ => Tone::None,
        }
    }
}

/// Một chữ cái trong từ đang gõ (chưa có thanh — thanh là thuộc tính của âm tiết).
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct Letter {
    /// Chữ gốc viết thường (`a`..`z`) hoặc ký tự khác (chữ số, `[`…) giữ nguyên.
    pub base: char,
    pub mark: Mark,
    pub upper: bool,
    /// Móc của `u` được thêm ngầm khi `w`/`7` áp lên cặp `uo`.
    pub implicit: bool,
    /// Chữ `ư` được chèn bởi phím `w` đứng riêng.
    pub inserted: bool,
}

impl Letter {
    pub fn plain(ch: char) -> Letter {
        let upper = ch.is_uppercase();
        let base = if ch.is_ascii_alphabetic() {
            ch.to_ascii_lowercase()
        } else {
            ch
        };
        Letter {
            base,
            mark: Mark::None,
            upper,
            implicit: false,
            inserted: false,
        }
    }

    pub fn is_vowel(&self) -> bool {
        is_vowel_base(self.base)
    }

    /// Ký tự (không thanh, viết thường) — dùng để so khớp với bảng vần.
    pub fn lower_char(&self) -> char {
        compose(self.base, self.mark, Tone::None, false).unwrap_or(self.base)
    }

    /// Ký tự hiển thị, có thể kèm thanh.
    pub fn render(&self, tone: Tone) -> char {
        if let Some(c) = compose(self.base, self.mark, tone, self.upper) {
            return c;
        }
        if self.upper {
            self.base.to_ascii_uppercase()
        } else {
            self.base
        }
    }
}

pub fn is_vowel_base(c: char) -> bool {
    matches!(c, 'a' | 'e' | 'i' | 'o' | 'u' | 'y')
}

/// Bảng nguyên âm: (chữ gốc, dấu phụ, 6 dạng thường theo thanh, 6 dạng hoa).
/// Thứ tự thanh: không, sắc, huyền, hỏi, ngã, nặng.
const VOWELS: [(char, Mark, [char; 6], [char; 6]); 12] = [
    (
        'a',
        Mark::None,
        ['a', 'á', 'à', 'ả', 'ã', 'ạ'],
        ['A', 'Á', 'À', 'Ả', 'Ã', 'Ạ'],
    ),
    (
        'a',
        Mark::Breve,
        ['ă', 'ắ', 'ằ', 'ẳ', 'ẵ', 'ặ'],
        ['Ă', 'Ắ', 'Ằ', 'Ẳ', 'Ẵ', 'Ặ'],
    ),
    (
        'a',
        Mark::Circumflex,
        ['â', 'ấ', 'ầ', 'ẩ', 'ẫ', 'ậ'],
        ['Â', 'Ấ', 'Ầ', 'Ẩ', 'Ẫ', 'Ậ'],
    ),
    (
        'e',
        Mark::None,
        ['e', 'é', 'è', 'ẻ', 'ẽ', 'ẹ'],
        ['E', 'É', 'È', 'Ẻ', 'Ẽ', 'Ẹ'],
    ),
    (
        'e',
        Mark::Circumflex,
        ['ê', 'ế', 'ề', 'ể', 'ễ', 'ệ'],
        ['Ê', 'Ế', 'Ề', 'Ể', 'Ễ', 'Ệ'],
    ),
    (
        'i',
        Mark::None,
        ['i', 'í', 'ì', 'ỉ', 'ĩ', 'ị'],
        ['I', 'Í', 'Ì', 'Ỉ', 'Ĩ', 'Ị'],
    ),
    (
        'o',
        Mark::None,
        ['o', 'ó', 'ò', 'ỏ', 'õ', 'ọ'],
        ['O', 'Ó', 'Ò', 'Ỏ', 'Õ', 'Ọ'],
    ),
    (
        'o',
        Mark::Circumflex,
        ['ô', 'ố', 'ồ', 'ổ', 'ỗ', 'ộ'],
        ['Ô', 'Ố', 'Ồ', 'Ổ', 'Ỗ', 'Ộ'],
    ),
    (
        'o',
        Mark::Horn,
        ['ơ', 'ớ', 'ờ', 'ở', 'ỡ', 'ợ'],
        ['Ơ', 'Ớ', 'Ờ', 'Ở', 'Ỡ', 'Ợ'],
    ),
    (
        'u',
        Mark::None,
        ['u', 'ú', 'ù', 'ủ', 'ũ', 'ụ'],
        ['U', 'Ú', 'Ù', 'Ủ', 'Ũ', 'Ụ'],
    ),
    (
        'u',
        Mark::Horn,
        ['ư', 'ứ', 'ừ', 'ử', 'ữ', 'ự'],
        ['Ư', 'Ứ', 'Ừ', 'Ử', 'Ữ', 'Ự'],
    ),
    (
        'y',
        Mark::None,
        ['y', 'ý', 'ỳ', 'ỷ', 'ỹ', 'ỵ'],
        ['Y', 'Ý', 'Ỳ', 'Ỷ', 'Ỹ', 'Ỵ'],
    ),
];

/// Dựng một ký tự NFC từ chữ gốc + dấu phụ + thanh. `None` nếu tổ hợp không tồn tại.
pub fn compose(base: char, mark: Mark, tone: Tone, upper: bool) -> Option<char> {
    if base == 'd' && mark == Mark::Stroke {
        return Some(if upper { 'Đ' } else { 'đ' });
    }
    for (b, m, lower, up) in VOWELS.iter() {
        if *b == base && *m == mark {
            let t = tone.index();
            return Some(if upper { up[t] } else { lower[t] });
        }
    }
    if mark == Mark::None && tone == Tone::None && base.is_ascii_lowercase() {
        return Some(if upper {
            base.to_ascii_uppercase()
        } else {
            base
        });
    }
    None
}

/// Tách một ký tự thành (chữ gốc, dấu phụ, thanh, hoa?). Chỉ cho chữ Latin/tiếng Việt.
pub fn decompose(c: char) -> Option<(char, Mark, Tone, bool)> {
    if c.is_ascii_alphabetic() {
        return Some((
            c.to_ascii_lowercase(),
            Mark::None,
            Tone::None,
            c.is_ascii_uppercase(),
        ));
    }
    match c {
        'đ' => return Some(('d', Mark::Stroke, Tone::None, false)),
        'Đ' => return Some(('d', Mark::Stroke, Tone::None, true)),
        _ => {}
    }
    if (c as u32) < 0xC0 {
        return None;
    }
    for (b, m, lower, up) in VOWELS.iter() {
        for t in 0..6 {
            if lower[t] == c {
                return Some((*b, *m, Tone::from_index(t), false));
            }
            if up[t] == c {
                return Some((*b, *m, Tone::from_index(t), true));
            }
        }
    }
    None
}

/// Chuẩn hoá NFC cho chữ Latin/tiếng Việt: gộp chữ gốc + dấu kết hợp (U+0300 U+0301 U+0302
/// U+0303 U+0306 U+0309 U+031B U+0323) thành ký tự dựng sẵn. Ký tự khác giữ nguyên.
/// (Thư viện chuẩn Rust không có chuẩn hoá Unicode; engine chỉ cần phần tiếng Việt.)
pub fn nfc(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut it = s.chars().peekable();
    while let Some(c) = it.next() {
        let mut marks = Vec::new();
        while let Some(&m) = it.peek() {
            if (0x300..=0x36F).contains(&(m as u32)) {
                marks.push(m);
                it.next();
            } else {
                break;
            }
        }
        if marks.is_empty() {
            out.push(c);
            continue;
        }
        let composed = decompose(c).and_then(|(b, mut mk, mut t, up)| {
            for m in &marks {
                let (new_mk, new_t) = match m {
                    '\u{300}' => (None, Some(Tone::Grave)),
                    '\u{301}' => (None, Some(Tone::Acute)),
                    '\u{303}' => (None, Some(Tone::Tilde)),
                    '\u{309}' => (None, Some(Tone::Hook)),
                    '\u{323}' => (None, Some(Tone::Dot)),
                    '\u{302}' => (Some(Mark::Circumflex), None),
                    '\u{306}' => (Some(Mark::Breve), None),
                    '\u{31B}' => (Some(Mark::Horn), None),
                    _ => return None,
                };
                if let Some(x) = new_mk {
                    if mk != Mark::None {
                        return None;
                    }
                    mk = x;
                }
                if let Some(x) = new_t {
                    if t != Tone::None {
                        return None;
                    }
                    t = x;
                }
            }
            compose(b, mk, t, up)
        });
        match composed {
            Some(x) => out.push(x),
            None => {
                out.push(c);
                out.extend(marks);
            }
        }
    }
    out
}

#[cfg(test)]
mod tests {
    #[test]
    fn nfc_composes_vietnamese() {
        assert_eq!(super::nfc("vie\u{323}\u{302}t"), "việt");
        assert_eq!(super::nfc("Vie\u{302}\u{323}t Nam"), "Việt Nam");
        assert_eq!(super::nfc("u\u{31B}o\u{31B}\u{300}ng"), "ường");
        assert_eq!(super::nfc("x\u{301}"), "x\u{301}");
        assert_eq!(super::nfc("đc"), "đc");
    }

    use super::*;

    #[test]
    fn table_is_precomposed_and_roundtrips() {
        for (b, m, lower, up) in VOWELS.iter() {
            for t in 0..6 {
                for (c, is_up) in [(lower[t], false), (up[t], true)] {
                    assert!(!(0x300..=0x36F).contains(&(c as u32)));
                    assert_eq!(decompose(c), Some((*b, *m, Tone::from_index(t), is_up)));
                    assert_eq!(compose(*b, *m, Tone::from_index(t), is_up), Some(c));
                }
            }
        }
    }
}

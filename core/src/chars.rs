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

#[cfg(test)]
mod tests {
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

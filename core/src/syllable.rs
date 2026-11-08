//! Phân tích âm tiết, kiểm tra hợp lệ và vị trí đặt thanh. Xem `docs/ENGINE_RULES.md` §3, §5.

use crate::chars::{decompose, Letter, Mark, Tone};

/// Phụ âm đầu hoàn chỉnh (không kể rỗng).
const INITIALS: &[&str] = &[
    "b", "c", "ch", "d", "đ", "g", "gh", "gi", "h", "k", "kh", "l", "m", "n", "ng", "ngh", "nh",
    "p", "ph", "qu", "r", "s", "t", "th", "tr", "v", "x",
];

/// Vần hợp lệ (không thanh).
pub const RHYMES: &[&str] = &[
    "a", "ac", "ach", "ai", "am", "an", "ang", "anh", "ao", "ap", "at", "au", "ay", //
    "ăc", "ăm", "ăn", "ăng", "ăp", "ăt", //
    "âc", "âm", "ân", "âng", "âp", "ât", "âu", "ây", //
    "e", "ec", "em", "en", "eng", "eo", "ep", "et", //
    "ê", "êch", "êm", "ên", "ênh", "êng", "êp", "êt", "êu", //
    "i", "ia", "ich", "im", "in", "inh", "ip", "it", "iu", //
    "iêc", "iêm", "iên", "iêng", "iêp", "iêt", "iêu", //
    "yêm", "yên", "yêng", "yêt", "yêu", //
    "o", "oc", "oi", "om", "on", "ong", "op", "ot", //
    "oa", "oac", "oach", "oai", "oam", "oan", "oang", "oanh", "oap", "oat", "oay", //
    "oăc", "oăm", "oăn", "oăng", "oăt", //
    "oe", "oen", "oeo", "oet", //
    "ooc", "oong", //
    "ô", "ôc", "ôi", "ôm", "ôn", "ông", "ôp", "ôt", //
    "ơ", "ơi", "ơm", "ơn", "ơp", "ơt", //
    "u", "ua", "uc", "ui", "um", "un", "ung", "up", "ut", //
    "uân", "uâng", "uât", "uây", //
    "uê", "uêch", "uênh", //
    "uôc", "uôi", "uôm", "uôn", "uông", "uôt", //
    "uơ",  //
    "uy", "uya", "uych", "uynh", "uyp", "uyt", "uyu", "uyên", "uyêt", "uyêch", //
    "ư", "ưa", "ưc", "ưi", "ưm", "ưng", "ưt", "ưu", //
    "ươc", "ươi", "ươm", "ươn", "ương", "ươp", "ươt", "ươu", //
    "y",
];

/// Vần đứng sau `qu` (âm đệm `u` đã thuộc phụ âm đầu).
pub const QU_RHYMES: &[&str] = &[
    "a", "ac", "ach", "ai", "am", "an", "ang", "anh", "ao", "ap", "at", "au", "ay", //
    "ăc", "ăm", "ăn", "ăng", "ăp", "ăt", //
    "e", "en", "eo", "et", //
    "ân", "âng", "ât", "ây", //
    "ê", "êch", "ênh", "ên", "êt", //
    "y", "ych", "ynh", "yp", "yt", "yu", "yên", "yêt", "yêch", "ya", //
    "ơ", "ôc", "i", "in", "it",
];

const GLIDE_PREFIXES: &[&str] = &["oa", "oă", "oe", "uâ", "uê", "uy", "uơ"];

/// Ranh giới các phần của âm tiết trong dãy chữ cái:
/// `[0, ini)` phụ âm đầu, `[ini, vow)` cụm nguyên âm, `[vow, len)` phần sau.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Parts {
    pub ini: usize,
    pub vow: usize,
    pub len: usize,
}

pub fn split(letters: &[Letter]) -> Parts {
    let n = letters.len();
    let mut i = 0;
    while i < n && !letters[i].is_vowel() {
        i += 1;
    }
    // qu: `u` sau `q` thuộc phụ âm đầu.
    if i == 1
        && i < n
        && letters[0].base == 'q'
        && letters[1].base == 'u'
        && letters[1].mark == Mark::None
    {
        i = 2;
    }
    // gi: `i` sau `g` thuộc phụ âm đầu nếu sau đó còn nguyên âm.
    if i == 1
        && i + 1 < n
        && letters[0].base == 'g'
        && letters[1].base == 'i'
        && letters[1].mark == Mark::None
        && letters[2].is_vowel()
    {
        i = 2;
    }
    let ini = i;
    while i < n && letters[i].is_vowel() {
        i += 1;
    }
    Parts {
        ini,
        vow: i,
        len: n,
    }
}

fn lower_string(letters: &[Letter]) -> String {
    letters.iter().map(|l| l.lower_char()).collect()
}

fn is_initial_prefix(s: &str) -> bool {
    s.is_empty() || s == "q" || INITIALS.iter().any(|i| i.starts_with(s))
}

fn is_initial(s: &str) -> bool {
    s.is_empty() || INITIALS.contains(&s)
}

fn first_base(r: &str) -> char {
    r.chars()
        .next()
        .and_then(decompose)
        .map(|d| d.0)
        .unwrap_or(' ')
}

fn first_char(r: &str) -> char {
    r.chars().next().unwrap_or(' ')
}

fn is_glide(r: &str) -> bool {
    GLIDE_PREFIXES.iter().any(|p| r.starts_with(p))
}

/// Vần `r` (lấy từ bảng) có được phép đi sau phụ âm đầu `ini` không. §3.3
fn rhyme_allowed(ini: &str, r: &str) -> bool {
    let fb = first_base(r);
    let fc = first_char(r);
    let front = matches!(fc, 'i' | 'e' | 'ê' | 'y');
    match ini {
        "qu" => return QU_RHYMES.contains(&r),
        "k" => return front,
        "gh" | "ngh" => return matches!(fc, 'i' | 'e' | 'ê'),
        "c" | "ng" => {
            if front {
                return false;
            }
        }
        "g" => {
            if matches!(fc, 'e' | 'ê' | 'y') {
                return false;
            }
            if fc == 'i' {
                return matches!(r, "i" | "in" | "im" | "ip" | "it" | "ich" | "inh");
            }
        }
        "gi" if fb == 'i' || fb == 'y' || is_glide(r) => return false,
        _ => {}
    }
    if ini.is_empty() {
        if r.starts_with("iê") {
            return false;
        }
    } else if r.starts_with("yê") {
        return false;
    }
    if r == "uơ" {
        return matches!(ini, "h" | "th" | "kh");
    }
    true
}

fn table_for(ini: &str) -> &'static [&'static str] {
    if ini == "qu" {
        QU_RHYMES
    } else {
        RHYMES
    }
}

/// `cur` là tiền tố yếu của `r`: cùng chữ gốc, dấu phụ trùng hoặc chưa có.
fn weak_prefix(cur: &[Letter], r: &str) -> bool {
    let mut it = r.chars();
    for l in cur {
        let Some(c) = it.next() else {
            return false;
        };
        let Some((b, m, _, _)) = decompose(c) else {
            return false;
        };
        if b != l.base || (l.mark != m && l.mark != Mark::None) {
            return false;
        }
    }
    true
}

fn all_letters_ok(letters: &[Letter]) -> bool {
    letters
        .iter()
        .all(|l| l.base.is_ascii_lowercase() && !matches!(l.base, 'f' | 'j' | 'w' | 'z'))
}

/// Hợp lệ tiền tố: có thể trở thành âm tiết hợp lệ khi gõ thêm. §3.5
pub fn is_valid_prefix(letters: &[Letter]) -> bool {
    if letters.is_empty() {
        return true;
    }
    if !all_letters_ok(letters) {
        return false;
    }
    let p = split(letters);
    let ini = lower_string(&letters[..p.ini]);
    if p.vow == p.ini {
        // Chưa có nguyên âm (hoặc chỉ có `qu`).
        return p.ini == p.len && is_initial_prefix(&ini);
    }
    if !is_initial(&ini) {
        return false;
    }
    let rest = &letters[p.ini..];
    if rest[p.vow - p.ini..].iter().any(|l| l.is_vowel()) {
        return false;
    }
    table_for(&ini)
        .iter()
        .any(|r| rhyme_allowed(&ini, r) && weak_prefix(rest, r))
}

/// Hợp lệ đầy đủ (dùng khi chốt từ). §3.5
pub fn is_valid_full(letters: &[Letter], tone: Tone) -> bool {
    if letters.is_empty() || !all_letters_ok(letters) {
        return false;
    }
    let p = split(letters);
    if p.vow == p.ini {
        return false;
    }
    let ini = lower_string(&letters[..p.ini]);
    if !is_initial(&ini) {
        return false;
    }
    let rhyme = lower_string(&letters[p.ini..]);
    if !table_for(&ini).contains(&rhyme.as_str()) || !rhyme_allowed(&ini, &rhyme) {
        return false;
    }
    let stop = rhyme.ends_with('c')
        || rhyme.ends_with("ch")
        || rhyme.ends_with('p')
        || rhyme.ends_with('t');
    !stop || matches!(tone, Tone::Acute | Tone::Dot)
}

/// Có nguyên âm nào trong cụm nguyên âm (để nhận phím thanh) không.
pub fn has_vowel(letters: &[Letter]) -> bool {
    let p = split(letters);
    p.vow > p.ini
}

/// Vị trí chữ mang thanh. §5
pub fn tone_position(letters: &[Letter], new_style: bool) -> Option<usize> {
    let p = split(letters);
    if p.vow == p.ini {
        return None;
    }
    let (s, e) = (p.ini, p.vow);
    if let Some(i) = (s..e)
        .rev()
        .find(|&i| matches!(letters[i].mark, Mark::Circumflex | Mark::Breve | Mark::Horn))
    {
        return Some(i);
    }
    if e < p.len {
        return Some(e - 1);
    }
    match e - s {
        1 => Some(s),
        2 => {
            let pair = (letters[s].base, letters[s + 1].base);
            // `oo` (xoong, boóng) là một nguyên âm dài: thanh ở chữ o thứ hai.
            if pair == ('o', 'o')
                || (new_style && matches!(pair, ('o', 'a') | ('o', 'e') | ('u', 'y')))
            {
                Some(s + 1)
            } else {
                Some(s)
            }
        }
        _ => Some(s + 1),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn letters(s: &str) -> Vec<Letter> {
        s.chars()
            .map(|c| {
                let (b, m, _, up) = decompose(c).unwrap_or((c, Mark::None, Tone::None, false));
                Letter {
                    base: b,
                    mark: m,
                    upper: up,
                    implicit: false,
                    inserted: false,
                }
            })
            .collect()
    }

    #[test]
    fn tables_are_well_formed() {
        for r in RHYMES.iter().chain(QU_RHYMES.iter()) {
            for c in r.chars() {
                assert!(decompose(c).is_some(), "{r}");
            }
        }
    }

    #[test]
    fn full_validity() {
        for (w, t, ok) in [
            ("tiêng", Tone::Acute, true),
            ("viêt", Tone::Dot, true),
            ("viêt", Tone::None, false),
            ("quôc", Tone::Acute, true),
            ("gin", Tone::Grave, true),
            ("ci", Tone::None, false),
            ("ke", Tone::None, true),
            ("ka", Tone::None, false),
            ("nghe", Tone::None, true),
            ("nge", Tone::None, false),
            ("yên", Tone::None, true),
            ("tyên", Tone::None, false),
            ("iên", Tone::None, false),
            ("thuơ", Tone::Hook, true),
            ("nguơ", Tone::None, false),
            ("lă", Tone::None, false),
            ("xoong", Tone::None, true),
        ] {
            assert_eq!(is_valid_full(&letters(w), t), ok, "{w}");
        }
    }

    #[test]
    fn prefix_validity() {
        for (w, ok) in [
            ("ngh", true),
            ("str", false),
            ("tie", true),
            ("khuye", true),
            ("ưo", true),
            ("wit", false),
            ("toân", false),
            ("ưit", false),
        ] {
            assert_eq!(is_valid_prefix(&letters(w)), ok, "{w}");
        }
    }
}

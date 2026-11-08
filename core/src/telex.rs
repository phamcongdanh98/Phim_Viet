//! Bảng phím Telex / Simple Telex.

use crate::chars::{Mark, Tone};
use crate::compose::Action;
use crate::config::{Config, InputMethod};

pub(crate) fn action(lower: char, cfg: &Config) -> Action {
    let simple = cfg.method == InputMethod::SimpleTelex;
    match lower {
        's' => Action::Tone(Tone::Acute),
        'f' => Action::Tone(Tone::Grave),
        'r' => Action::Tone(Tone::Hook),
        'x' => Action::Tone(Tone::Tilde),
        'j' => Action::Tone(Tone::Dot),
        'z' => Action::ClearTone,
        'a' | 'e' | 'o' => Action::Circumflex(Some(lower)),
        'w' => Action::HornBreve {
            insert_u: !simple && cfg.w_as_u,
        },
        'd' => Action::Stroke,
        '[' if !simple && cfg.brackets => Action::Insert('o', Mark::Horn),
        ']' if !simple && cfg.brackets => Action::Insert('u', Mark::Horn),
        _ => Action::Letter,
    }
}

/// Phím Telex tạo ra dấu phụ `m` cho chữ gốc `base` (dùng để dựng raw chuẩn).
pub(crate) fn mark_key(base: char, m: Mark) -> Option<char> {
    match m {
        Mark::None => None,
        Mark::Circumflex => Some(base),
        Mark::Breve | Mark::Horn => Some('w'),
        Mark::Stroke => Some('d'),
    }
}

pub(crate) fn tone_key(t: Tone) -> Option<char> {
    match t {
        Tone::None => None,
        Tone::Acute => Some('s'),
        Tone::Grave => Some('f'),
        Tone::Hook => Some('r'),
        Tone::Tilde => Some('x'),
        Tone::Dot => Some('j'),
    }
}

pub(crate) fn is_word_key(ch: char, cfg: &Config) -> bool {
    ch.is_ascii_alphabetic()
        || (cfg.method == InputMethod::Telex && cfg.brackets && (ch == '[' || ch == ']'))
}

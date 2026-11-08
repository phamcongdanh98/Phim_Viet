//! Bảng phím VNI.

use crate::chars::{Mark, Tone};
use crate::compose::Action;

pub(crate) fn action(lower: char) -> Action {
    match lower {
        '1' => Action::Tone(Tone::Acute),
        '2' => Action::Tone(Tone::Grave),
        '3' => Action::Tone(Tone::Hook),
        '4' => Action::Tone(Tone::Tilde),
        '5' => Action::Tone(Tone::Dot),
        '0' => Action::ClearTone,
        '6' => Action::Circumflex(None),
        '7' => Action::Horn,
        '8' => Action::Breve,
        '9' => Action::Stroke,
        _ => Action::Letter,
    }
}

pub(crate) fn mark_key(m: Mark) -> Option<char> {
    match m {
        Mark::None => None,
        Mark::Circumflex => Some('6'),
        Mark::Horn => Some('7'),
        Mark::Breve => Some('8'),
        Mark::Stroke => Some('9'),
    }
}

pub(crate) fn tone_key(t: Tone) -> Option<char> {
    match t {
        Tone::None => None,
        Tone::Acute => Some('1'),
        Tone::Grave => Some('2'),
        Tone::Hook => Some('3'),
        Tone::Tilde => Some('4'),
        Tone::Dot => Some('5'),
    }
}

/// Chữ số chỉ là phím VNI khi đang có từ dở.
pub(crate) fn is_word_key(ch: char, composing: bool) -> bool {
    ch.is_ascii_alphabetic() || (composing && ch.is_ascii_digit())
}

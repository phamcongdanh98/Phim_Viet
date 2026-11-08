//! Dựng lại raw từ chuỗi hiển thị (cho backspace) — ENGINE_RULES §8.

use crate::chars::{decompose, Tone};
use crate::config::{Config, InputMethod};
use crate::{telex, vni, KeyInput};

/// Raw chuẩn: chữ gốc + phím dấu phụ ngay sau, phím thanh ở cuối.
/// `None` nếu chuỗi có ký tự không phải chữ hoặc có hơn một thanh.
pub(crate) fn canonical_raw(s: &str, cfg: &Config) -> Option<Vec<KeyInput>> {
    let vni = cfg.method == InputMethod::Vni;
    let mut keys = Vec::with_capacity(s.len() + 3);
    let mut tone = Tone::None;
    let mut prev: Option<(char, crate::chars::Mark)> = None;
    for c in s.chars() {
        let (base, mark, t, upper) = decompose(c)?;
        // Telex `oo` (xoong): chữ o thứ hai cần thêm một phím o để huỷ mũ.
        let plain = crate::chars::Mark::None;
        if !vni && mark == plain && matches!(base, 'a' | 'e' | 'o') && prev == Some((base, plain)) {
            keys.push(KeyInput::new(base));
        }
        prev = Some((base, mark));
        if t != Tone::None {
            if tone != Tone::None {
                return None;
            }
            tone = t;
        }
        let b = if upper {
            base.to_ascii_uppercase()
        } else {
            base
        };
        keys.push(KeyInput::new(b));
        let mk = if vni {
            vni::mark_key(mark)
        } else {
            telex::mark_key(base, mark)
        };
        if let Some(k) = mk {
            keys.push(KeyInput::new(if upper {
                k.to_ascii_uppercase()
            } else {
                k
            }));
        }
    }
    let tk = if vni {
        vni::tone_key(tone)
    } else {
        telex::tone_key(tone)
    };
    if let Some(k) = tk {
        keys.push(KeyInput::new(k));
    }
    Some(keys)
}

/// Dùng nguyên các ký tự làm phím.
pub(crate) fn plain_raw(s: &str) -> Vec<KeyInput> {
    s.chars().map(KeyInput::new).collect()
}

/// Đóng băng: các ký tự được giữ nguyên văn, không biến đổi.
pub(crate) fn frozen_raw(s: &str) -> Vec<KeyInput> {
    s.chars()
        .map(|c| KeyInput {
            ch: c,
            literal: true,
        })
        .collect()
}

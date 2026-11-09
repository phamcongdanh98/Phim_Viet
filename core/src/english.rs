//! Từ tiếng Anh có cặp chữ trùng phím Telex gõ đôi (`ss ff rr xx jj dd aa ee oo ww`).
//!
//! Gõ đôi phím dấu ngay sau khi đặt dấu là **huỷ dấu** (`tesst` → `test`). Nhưng nhiều từ tiếng Anh
//! có sẵn cặp đó (`pass`, `issue`, `success`). Danh sách này phân biệt hai trường hợp (ENGINE_RULES §7).
//! Nguồn: `/usr/share/dict/words` (Webster's Second International, 1934 — hết bản quyền),
//! sinh bằng `scripts/gen_en_double.sh`.

use std::sync::OnceLock;

static DATA: &str = include_str!("../data/en_double.txt");

/// Đuôi biến tố thường gặp: `passes` → `pass`, `passwords` → `password`.
const SUFFIXES: &[&str] = &[
    "s", "es", "ed", "d", "ing", "er", "ers", "est", "ly", "ness", "ment", "ments", "ion", "ions",
];

fn words() -> &'static [&'static str] {
    static W: OnceLock<Vec<&'static str>> = OnceLock::new();
    W.get_or_init(|| {
        let mut v: Vec<&'static str> = DATA
            .lines()
            .map(str::trim)
            .filter(|l| !l.is_empty() && !l.starts_with('#'))
            .collect();
        v.sort_unstable();
        v.dedup();
        v
    })
}

fn exact(w: &str) -> bool {
    words().binary_search(&w).is_ok()
}

/// `raw` (chữ thường ASCII) là một từ tiếng Anh trong danh sách, kể cả dạng có đuôi biến tố.
pub fn is_word(raw: &str) -> bool {
    if !raw.bytes().all(|b| b.is_ascii_lowercase()) {
        return false;
    }
    exact(raw)
        || SUFFIXES.iter().any(|s| {
            raw.strip_suffix(s)
                .is_some_and(|stem| stem.len() >= 4 && exact(stem))
        })
}

/// `raw` là từ hoặc đầu của một từ trong danh sách (đang gõ dở `issu…`).
pub fn is_prefix(raw: &str) -> bool {
    if raw.is_empty() || !raw.bytes().all(|b| b.is_ascii_lowercase()) {
        return false;
    }
    let w = words();
    let i = w.partition_point(|x| *x < raw);
    w.get(i).is_some_and(|x| x.starts_with(raw)) || is_word(raw)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lookup() {
        for w in [
            "pass",
            "issue",
            "success",
            "address",
            "passwords",
            "classes",
            "offer",
            "error",
            "daddy",
            "cocoon",
            "off",
        ] {
            assert!(is_word(w), "{w}");
        }
        for w in ["tesst", "besst", "lisst", "texxt", "ass", "thiss", "Pass"] {
            assert!(!is_word(w), "{w}");
        }
        assert!(is_prefix("issu"));
        assert!(is_prefix("passw"));
        assert!(!is_prefix("tesst"));
    }
}

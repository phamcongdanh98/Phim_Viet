//! Gõ tắt: tra từ tắt (không phân biệt hoa thường) và giữ kiểu hoa của từ gõ.

/// Tìm cụm thay thế cho `typed`. Kiểu hoa:
/// toàn thường → nguyên văn; chữ đầu hoa → hoa chữ đầu; toàn hoa (≥ 2 chữ) → hoa cả cụm.
pub fn lookup(macros: &[(String, String)], typed: &str) -> Option<String> {
    if typed.is_empty() {
        return None;
    }
    let key = typed.to_lowercase();
    macros
        .iter()
        .find(|(k, _)| k.to_lowercase() == key)
        .map(|(_, v)| adapt_case(typed, v))
}

pub fn adapt_case(typed: &str, value: &str) -> String {
    let letters: Vec<char> = typed.chars().filter(|c| c.is_alphabetic()).collect();
    if letters.is_empty() || letters.iter().all(|c| !c.is_uppercase()) {
        return value.to_string();
    }
    if letters.len() >= 2 && letters.iter().all(|c| !c.is_lowercase()) {
        return value.to_uppercase();
    }
    if letters[0].is_uppercase() && letters[1..].iter().all(|c| !c.is_uppercase()) {
        let mut it = value.chars();
        return match it.next() {
            Some(f) => f.to_uppercase().chain(it).collect(),
            None => String::new(),
        };
    }
    value.to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn case_rules() {
        let m = vec![
            ("vn".to_string(), "Việt Nam".to_string()),
            ("ko".into(), "không".into()),
        ];
        assert_eq!(lookup(&m, "vn").as_deref(), Some("Việt Nam"));
        assert_eq!(lookup(&m, "Vn").as_deref(), Some("Việt Nam"));
        assert_eq!(lookup(&m, "VN").as_deref(), Some("VIỆT NAM"));
        assert_eq!(lookup(&m, "Ko").as_deref(), Some("Không"));
        assert_eq!(lookup(&m, "KO").as_deref(), Some("KHÔNG"));
        assert_eq!(lookup(&m, "vN").as_deref(), Some("Việt Nam"));
        assert_eq!(lookup(&m, "x"), None);
    }
}

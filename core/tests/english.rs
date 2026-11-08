//! Tự khôi phục tiếng Anh (ENGINE_RULES §7).

mod common;
use common::*;
use std::collections::BTreeSet;

fn restored(word: &str) -> bool {
    typed(&telex(), word) == word
}

fn curated() -> Vec<String> {
    let set: BTreeSet<String> = include_str!("data/english_300.txt")
        .lines()
        .map(str::trim)
        .filter(|l| !l.is_empty() && !l.starts_with('#'))
        .map(String::from)
        .collect();
    set.into_iter().collect()
}

#[test]
fn curated_english_words_are_restored() {
    let words = curated();
    assert!(words.len() >= 300, "danh sách chỉ có {} từ", words.len());
    let failed: Vec<String> = words
        .iter()
        .filter(|w| !restored(w))
        .map(|w| format!("{w}→{}", typed(&telex(), w)))
        .collect();
    let rate = 100.0 * (words.len() - failed.len()) as f64 / words.len() as f64;
    println!(
        "Tự khôi phục (300 từ tự soạn): {}/{} = {rate:.1}%  — không khôi phục: {}",
        words.len() - failed.len(),
        words.len(),
        failed.join(", ")
    );
    assert!(rate >= 95.0, "tỷ lệ {rate:.1}% < 95%");
}

/// Báo cáo trên `/usr/share/dict/words` (không assert — từ điển chứa nhiều từ hiếm).
#[test]
fn dict_words_report() {
    let Ok(text) = std::fs::read_to_string("/usr/share/dict/words") else {
        println!("không có /usr/share/dict/words — bỏ qua");
        return;
    };
    let words: Vec<&str> = text
        .lines()
        .filter(|w| w.len() >= 2 && w.len() <= 10 && w.chars().all(|c| c.is_ascii_lowercase()))
        .collect();
    let ok = words.iter().filter(|w| restored(w)).count();
    println!(
        "/usr/share/dict/words (≤10 ký tự, chữ thường): {ok}/{} = {:.1}% giữ nguyên",
        words.len(),
        100.0 * ok as f64 / words.len() as f64
    );
}

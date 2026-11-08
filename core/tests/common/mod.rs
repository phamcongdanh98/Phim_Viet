//! Tiện ích test dùng chung + bộ sinh âm tiết tiếng Việt độc lập với bảng của engine.
#![allow(dead_code)]

use phimviet_core::chars::{compose, decompose, Mark, Tone};
use phimviet_core::{Boundary, Config, Engine, InputMethod, KeyInput, Output, ToneStyle};

pub const BS: char = '\u{8}';
pub const ESC: char = '\u{1b}';

pub fn cfg(method: InputMethod) -> Config {
    Config {
        method,
        ..Config::default()
    }
}

pub fn telex() -> Config {
    cfg(InputMethod::Telex)
}

pub fn vni() -> Config {
    cfg(InputMethod::Vni)
}

pub fn old_style(mut c: Config) -> Config {
    c.tone_style = ToneStyle::Old;
    c
}

/// Mô phỏng shell: tài liệu = phần đã chốt + chữ đang hiển thị.
pub struct Sim {
    pub engine: Engine,
    pub doc: String,
}

impl Sim {
    pub fn new(c: &Config) -> Self {
        Sim {
            engine: Engine::new(c.clone()),
            doc: String::new(),
        }
    }

    pub fn key(&mut self, c: char) {
        match c {
            BS => match self.engine.backspace() {
                Output::Unchanged => {
                    self.doc.pop();
                }
                Output::Composing(_) => {}
                o => panic!("backspace trả {o:?}"),
            },
            ESC => {
                if let Output::Commit { text, .. } = self.engine.restore_raw() {
                    self.doc.push_str(&text);
                }
            }
            c => match self.engine.process(KeyInput::new(c)) {
                Output::Unchanged => self.doc.push(c),
                Output::Composing(_) => {}
                Output::Commit { text, pass_through } => {
                    self.doc.push_str(&text);
                    if pass_through {
                        self.doc.push(c);
                    }
                }
            },
        }
    }

    pub fn keys(&mut self, s: &str) {
        for c in s.chars() {
            self.key(c);
        }
    }

    /// Tài liệu nhìn thấy (chưa chốt từ cuối).
    pub fn shown(&self) -> String {
        format!("{}{}", self.doc, self.engine.composing())
    }

    /// Chốt từ cuối bằng phím cách (không thêm dấu cách).
    pub fn finish(mut self) -> String {
        if let Output::Commit { text, .. } = self.engine.commit(Boundary::Space) {
            self.doc.push_str(&text);
        }
        self.doc
    }
}

pub fn typed(c: &Config, keys: &str) -> String {
    let mut s = Sim::new(c);
    s.keys(keys);
    s.finish()
}

pub fn shown(c: &Config, keys: &str) -> String {
    let mut s = Sim::new(c);
    s.keys(keys);
    s.shown()
}

// ---------------------------------------------------------------------------
// Bộ sinh âm tiết: phụ âm đầu × (âm đệm) × âm chính × âm cuối × thanh.
// ---------------------------------------------------------------------------

pub const ONSETS: &[&str] = &[
    "", "b", "c", "ch", "d", "đ", "g", "gh", "gi", "h", "k", "kh", "l", "m", "n", "ng", "ngh",
    "nh", "p", "ph", "qu", "r", "s", "t", "th", "tr", "v", "x",
];

/// (âm chính, các phần đuôi). Phần đuôi có thể là bán nguyên âm (i o u y a) hoặc phụ âm cuối.
const NUCLEI: &[(&str, &[&str])] = &[
    (
        "a",
        &[
            "", "c", "ch", "i", "m", "n", "ng", "nh", "o", "p", "t", "u", "y",
        ],
    ),
    ("ă", &["c", "m", "n", "ng", "p", "t"]),
    ("â", &["c", "m", "n", "ng", "p", "t", "u", "y"]),
    ("e", &["", "c", "m", "n", "ng", "o", "p", "t"]),
    ("ê", &["", "ch", "m", "n", "ng", "nh", "p", "t", "u"]),
    ("i", &["", "a", "ch", "m", "n", "nh", "p", "t", "u"]),
    ("iê", &["c", "m", "n", "ng", "p", "t", "u"]),
    ("o", &["", "c", "i", "m", "n", "ng", "p", "t"]),
    ("oo", &["c", "ng"]),
    ("ô", &["", "c", "i", "m", "n", "ng", "p", "t"]),
    ("ơ", &["", "i", "m", "n", "p", "t"]),
    ("u", &["", "a", "c", "i", "m", "n", "ng", "p", "t"]),
    ("uô", &["c", "i", "m", "n", "ng", "t"]),
    ("ư", &["", "a", "c", "i", "m", "ng", "t", "u"]),
    ("ươ", &["c", "i", "m", "n", "ng", "p", "t", "u"]),
    ("y", &[""]),
];

/// Vần có âm đệm: (âm đệm + âm chính, đuôi).
const GLIDED: &[(&str, &[&str])] = &[
    (
        "oa",
        &["", "c", "ch", "i", "m", "n", "ng", "nh", "p", "t", "y"],
    ),
    ("oă", &["c", "m", "n", "ng", "t"]),
    ("oe", &["", "n", "o", "t"]),
    ("uâ", &["n", "ng", "t", "y"]),
    ("uê", &["", "ch", "nh"]),
    ("uy", &["", "a", "ch", "nh", "p", "t", "u"]),
    ("uyê", &["n", "t", "ch"]),
    ("uơ", &[""]),
];

#[derive(Clone, Debug)]
pub struct Syl {
    pub onset: &'static str,
    /// Vần viết (không thanh), ví dụ "iêng", "ươi".
    pub rhyme: String,
    pub tone: Tone,
    pub text: String,
}

fn is_v(c: char) -> bool {
    decompose(c).is_some_and(|d| matches!(d.0, 'a' | 'e' | 'i' | 'o' | 'u' | 'y'))
}

fn stop(r: &str) -> bool {
    r.ends_with('c') || r.ends_with("ch") || r.ends_with('p') || r.ends_with('t')
}

/// Đặt thanh (hiện thực riêng của bộ sinh, theo ENGINE_RULES §5).
pub fn place_tone(rhyme: &str, tone: Tone, new_style: bool) -> String {
    let chars: Vec<char> = rhyme.chars().collect();
    let vowels: Vec<usize> = (0..chars.len()).filter(|&i| is_v(chars[i])).collect();
    let has_coda = vowels.last().is_some_and(|&l| l + 1 < chars.len());
    let marked = vowels
        .iter()
        .rev()
        .find(|&&i| matches!(chars[i], 'â' | 'ă' | 'ê' | 'ô' | 'ơ' | 'ư'))
        .copied();
    let pos = if let Some(m) = marked {
        m
    } else if has_coda {
        *vowels.last().unwrap()
    } else if vowels.len() >= 3 {
        vowels[1]
    } else if vowels.len() == 2 {
        let pair: String = [chars[vowels[0]], chars[vowels[1]]].iter().collect();
        if new_style && matches!(pair.as_str(), "oa" | "oe" | "uy") {
            vowels[1]
        } else {
            vowels[0]
        }
    } else {
        vowels[0]
    };
    chars
        .iter()
        .enumerate()
        .map(|(i, &c)| {
            if i == pos {
                let (b, m, _, up) = decompose(c).unwrap();
                compose(b, m, tone, up).unwrap()
            } else {
                c
            }
        })
        .collect()
}

fn onset_ok(onset: &str, rhyme: &str, glided: bool) -> bool {
    let fc = rhyme.chars().next().unwrap();
    let front = matches!(fc, 'i' | 'e' | 'ê' | 'y');
    match onset {
        "k" => front,
        "gh" | "ngh" => matches!(fc, 'i' | 'e' | 'ê'),
        "c" | "ng" => !front,
        "g" => {
            if fc == 'i' {
                matches!(rhyme, "i" | "in" | "im" | "ip" | "it" | "ich" | "inh")
            } else {
                !front
            }
        }
        "gi" => !glided && fc != 'i' && fc != 'y',
        "qu" => false, // xử lý riêng
        _ => true,
    }
}

pub fn generate(new_style: bool) -> Vec<Syl> {
    let mut rhymes: Vec<(String, bool)> = Vec::new();
    for (n, ends) in NUCLEI {
        for e in *ends {
            rhymes.push((format!("{n}{e}"), false));
        }
    }
    for (n, ends) in GLIDED {
        for e in *ends {
            rhymes.push((format!("{n}{e}"), true));
        }
    }
    let mut out = Vec::new();
    for &onset in ONSETS {
        let mut list: Vec<String> = Vec::new();
        if onset == "qu" {
            for (r, glided) in &rhymes {
                if *glided {
                    // âm đệm viết là `u` sau q
                    let rest: String = r.chars().skip(1).collect();
                    if r == "uơ" || r.starts_with('o') || r.starts_with('u') {
                        list.push(rest);
                    }
                }
            }
            list.push("ôc".into());
        } else {
            for (r, glided) in &rhymes {
                if r == "uơ" && !matches!(onset, "h" | "th" | "kh") {
                    continue;
                }
                let mut r = r.clone();
                if onset.is_empty() && r.starts_with("iê") {
                    // không có `yêc`, `yêp`
                    if r == "iêc" || r == "iêp" {
                        continue;
                    }
                    r = r.replacen("iê", "yê", 1);
                }
                if onset_ok(onset, &r, *glided) {
                    list.push(r);
                }
            }
        }
        for r in list {
            for t in 0..6 {
                let tone = [
                    Tone::None,
                    Tone::Acute,
                    Tone::Grave,
                    Tone::Hook,
                    Tone::Tilde,
                    Tone::Dot,
                ][t];
                if stop(&r) && !matches!(tone, Tone::Acute | Tone::Dot) {
                    continue;
                }
                let text = format!("{onset}{}", place_tone(&r, tone, new_style));
                out.push(Syl {
                    onset,
                    rhyme: r.clone(),
                    tone,
                    text,
                });
            }
        }
    }
    out
}

// ---------------------------------------------------------------------------
// Sinh dãy phím theo nhiều thứ tự.
// ---------------------------------------------------------------------------

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Order {
    /// Dấu phụ ngay sau nguyên âm, thanh ở cuối.
    Canonical,
    /// Thanh ngay sau nguyên âm mang thanh.
    ToneAfterVowel,
    /// Chữ gốc trước, dấu phụ rồi thanh ở cuối.
    MarksAtEnd,
    /// Chữ gốc, thanh, rồi dấu phụ ở cuối.
    ToneThenMarks,
    /// Thanh ngay sau nguyên âm đầu tiên.
    ToneAfterFirstVowel,
}

pub const ORDERS: [Order; 5] = [
    Order::Canonical,
    Order::ToneAfterVowel,
    Order::MarksAtEnd,
    Order::ToneThenMarks,
    Order::ToneAfterFirstVowel,
];

fn tone_key(t: Tone, vni: bool) -> Option<char> {
    let i = match t {
        Tone::None => return None,
        Tone::Acute => 0,
        Tone::Grave => 1,
        Tone::Hook => 2,
        Tone::Tilde => 3,
        Tone::Dot => 4,
    };
    Some(if vni {
        ['1', '2', '3', '4', '5'][i]
    } else {
        ['s', 'f', 'r', 'x', 'j'][i]
    })
}

fn mark_key(base: char, m: Mark, vni: bool) -> Option<char> {
    match (m, vni) {
        (Mark::None, _) => None,
        (Mark::Circumflex, false) => Some(base),
        (Mark::Circumflex, true) => Some('6'),
        (Mark::Breve, false) | (Mark::Horn, false) => Some('w'),
        (Mark::Horn, true) => Some('7'),
        (Mark::Breve, true) => Some('8'),
        (Mark::Stroke, false) => Some('d'),
        (Mark::Stroke, true) => Some('9'),
    }
}

/// Dãy phím gõ ra `syl` theo thứ tự `order`. `None` nếu thứ tự không áp dụng được.
pub fn keys_for(syl: &Syl, order: Order, vni: bool) -> Option<String> {
    let text: Vec<char> = syl.text.chars().collect();
    let onset_len = syl.onset.chars().count();
    let tk = tone_key(syl.tone, vni);
    // vị trí chữ mang thanh trong text
    let tone_pos = text
        .iter()
        .position(|&c| decompose(c).is_some_and(|d| d.2 != Tone::None));
    let first_vowel = (onset_len..text.len()).find(|&i| is_v(text[i]));
    let oo = syl.rhyme.starts_with("oo");
    let mut keys = String::new();
    let mut deferred = String::new();
    let defer = matches!(order, Order::MarksAtEnd | Order::ToneThenMarks);
    if oo && defer {
        return None;
    }
    let mut horn_deferred = false;
    for (i, &c) in text.iter().enumerate() {
        let (b, m, _, up) = decompose(c)?;
        keys.push(if up { b.to_ascii_uppercase() } else { b });
        if oo && !vni && i == first_vowel.unwrap() {
            // `xooong`: o o → ô, o thứ ba (chữ o sau) huỷ.
            keys.push(if up { 'O' } else { 'o' });
        }
        if let Some(k) = mark_key(b, m, vni) {
            if defer {
                let is_horn = m == Mark::Horn;
                if !(is_horn && horn_deferred) {
                    deferred.push(k);
                }
                horn_deferred |= is_horn;
            } else {
                keys.push(k);
            }
        }
        let tone_here = match order {
            Order::ToneAfterVowel => Some(i) == tone_pos,
            Order::ToneAfterFirstVowel => Some(i) == first_vowel,
            _ => false,
        };
        if tone_here {
            if let Some(t) = tk {
                keys.push(t);
            }
        }
    }
    match order {
        Order::Canonical => keys.extend(tk),
        Order::MarksAtEnd => {
            keys.push_str(&deferred);
            keys.extend(tk);
        }
        Order::ToneThenMarks => {
            keys.extend(tk);
            keys.push_str(&deferred);
        }
        _ => {}
    }
    Some(keys)
}

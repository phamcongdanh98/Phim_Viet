//! Property test: dãy phím ngẫu nhiên không bao giờ panic, đầu ra luôn NFC, độ dài hợp lý.

mod common;
use common::*;
use phimviet_core::{Boundary, Config, Engine, InputMethod, KeyInput, Output, ToneStyle};

/// Bộ sinh số ngẫu nhiên tất định (xorshift64*).
struct Rng(u64);
impl Rng {
    fn next(&mut self) -> u64 {
        self.0 ^= self.0 >> 12;
        self.0 ^= self.0 << 25;
        self.0 ^= self.0 >> 27;
        self.0.wrapping_mul(0x2545_F491_4F6C_DD1D)
    }
    fn below(&mut self, n: usize) -> usize {
        (self.next() % n as u64) as usize
    }
}

const ALPHABET: &[char] = &[
    'a', 'e', 'o', 'u', 'i', 'y', 'w', 'd', 's', 'f', 'r', 'x', 'j', 'z', 'n', 'g', 'h', 't', 'c',
    'q', 'k', 'p', 'm', 'b', 'l', 'v', 'A', 'E', 'O', 'W', 'D', 'S', 'G', '0', '1', '2', '3', '4',
    '5', '6', '7', '8', '9', '[', ']', ' ', '.', ',', '\u{8}', '\u{1b}', 'é', '😀',
];

fn no_combining(s: &str) -> bool {
    s.chars().all(|c| !(0x300..=0x36F).contains(&(c as u32)))
}

fn check_text(s: &str, raw_len: usize, ctx: &str) {
    assert!(no_combining(s), "dấu kết hợp trong {s:?} ({ctx})");
    assert!(
        s.chars().count() <= raw_len.max(1) + 1,
        "chuỗi {s:?} dài hơn số phím {raw_len} ({ctx})"
    );
}

#[test]
fn random_sequences_never_panic() {
    let configs: Vec<Config> = [
        InputMethod::Telex,
        InputMethod::Vni,
        InputMethod::SimpleTelex,
    ]
    .iter()
    .flat_map(|&m| {
        [false, true].into_iter().map(move |flip| Config {
            method: m,
            tone_style: if flip { ToneStyle::Old } else { ToneStyle::New },
            spell_check: !flip,
            auto_restore: !flip,
            brackets: flip,
            macros: vec![("vn".into(), "Việt Nam".into())],
            ..Config::default()
        })
    })
    .collect();
    let mut rng = Rng(0x9E37_79B9_7F4A_7C15);
    let sequences = 100_000;
    for n in 0..sequences {
        let c = &configs[n % configs.len()];
        let mut e = Engine::new(c.clone());
        let len = 1 + rng.below(24);
        let mut keys = String::new();
        let mut typed_in_word = 0usize;
        for _ in 0..len {
            let k = ALPHABET[rng.below(ALPHABET.len())];
            keys.push(k);
            let out = match k {
                '\u{8}' => e.backspace(),
                '\u{1b}' => e.restore_raw(),
                _ => e.process(KeyInput::new(k)),
            };
            let ctx = format!("{keys:?} {:?}", c.method);
            match &out {
                Output::Composing(s) => {
                    if k != '\u{8}' {
                        typed_in_word += 1;
                    }
                    check_text(s, typed_in_word.max(64), &ctx);
                    assert_eq!(s, e.composing());
                }
                Output::Commit { text, .. } => {
                    check_text(text, 4096, &ctx);
                    typed_in_word = 0;
                    assert_eq!(e.composing(), "");
                }
                Output::Unchanged => {}
            }
            if !e.is_composing() {
                typed_in_word = 0;
            }
            // tính lại từ raw phải ra đúng chữ đang hiển thị (tất định)
            if e.is_composing() && !e.rendered().frozen {
                let again = phimviet_core::render_str(e.raw_text(), c);
                assert_eq!(again, e.composing(), "không tất định: {ctx}");
            }
        }
        if let Output::Commit { text, .. } = e.commit(Boundary::Focus) {
            check_text(&text, 4096, &keys);
        }
    }
    println!("đã chạy {sequences} dãy ngẫu nhiên");
}

#[test]
fn simulated_document_stays_nfc() {
    let mut rng = Rng(42);
    for _ in 0..2_000 {
        let mut s = Sim::new(&telex());
        for _ in 0..40 {
            s.key(ALPHABET[rng.below(ALPHABET.len())]);
        }
        assert!(no_combining(&s.shown()));
    }
}

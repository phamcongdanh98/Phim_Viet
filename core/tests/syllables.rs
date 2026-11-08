//! Test tổ hợp: mọi âm tiết sinh tự động phải gõ đúng bằng Telex và VNI theo nhiều thứ tự phím,
//! round-trip qua backspace, và hợp lệ theo engine.

mod common;
use common::*;
use phimviet_core::chars::decompose;
use phimviet_core::{Boundary, Config, Engine, InputMethod, KeyInput, Output};

fn run(c: &Config, keys: &str) -> (String, String) {
    let mut e = Engine::new(c.clone());
    for k in keys.chars() {
        e.process(KeyInput::new(k));
    }
    let shown = e.composing().to_string();
    let committed = match e.commit(Boundary::Space) {
        Output::Commit { text, .. } => text,
        o => panic!("{o:?}"),
    };
    (shown, committed)
}

fn check_all(c: &Config, new_style: bool) -> (usize, usize) {
    let vni = c.method == InputMethod::Vni;
    let syls = generate(new_style);
    let mut runs = 0;
    let mut failures = Vec::new();
    for s in &syls {
        for order in ORDERS {
            let Some(keys) = keys_for(s, order, vni) else {
                continue;
            };
            runs += 1;
            let (shown, committed) = run(c, &keys);
            if shown != s.text || committed != s.text {
                failures.push(format!(
                    "{:?} {keys:?} → hiển thị {shown:?}, chốt {committed:?}, cần {:?}",
                    order, s.text
                ));
            }
        }
    }
    if !failures.is_empty() {
        let n = failures.len();
        failures.truncate(40);
        panic!("{n} lỗi / {runs} lần gõ:\n{}", failures.join("\n"));
    }
    (syls.len(), runs)
}

#[test]
fn generator_has_enough_syllables() {
    let n = generate(true).len();
    println!("số âm tiết sinh ra: {n}");
    assert!(n >= 15_000, "chỉ có {n} âm tiết");
}

#[test]
fn all_syllables_telex() {
    let (n, runs) = check_all(&telex(), true);
    println!("Telex: {n} âm tiết, {runs} lần gõ");
}

#[test]
fn all_syllables_telex_old_style() {
    let (n, runs) = check_all(&old_style(telex()), false);
    println!("Telex kiểu cũ: {n} âm tiết, {runs} lần gõ");
}

#[test]
fn all_syllables_vni() {
    let (n, runs) = check_all(&vni(), true);
    println!("VNI: {n} âm tiết, {runs} lần gõ");
}

#[test]
fn all_syllables_simple_telex() {
    check_all(&cfg(InputMethod::SimpleTelex), true);
}

#[test]
fn all_syllables_uppercase_and_title() {
    let c = telex();
    let mut bad = Vec::new();
    for s in generate(true).iter().step_by(7) {
        for variant in [s.text.to_uppercase(), {
            let mut it = s.text.chars();
            let f = it.next().unwrap();
            f.to_uppercase().chain(it).collect::<String>()
        }] {
            let syl = Syl {
                text: variant.clone(),
                ..s.clone()
            };
            let keys = keys_for(&syl, Order::Canonical, false).unwrap();
            let (shown, committed) = run(&c, &keys);
            if shown != variant || committed != variant {
                bad.push(format!("{keys} → {shown}/{committed}, cần {variant}"));
            }
        }
    }
    assert!(bad.is_empty(), "{}", bad[..bad.len().min(30)].join("\n"));
}

/// Gõ âm tiết, xoá dần k ký tự, kiểm tra hiển thị, rồi gõ lại phần đã xoá.
fn backspace_roundtrip(c: &Config) {
    let vni = c.method == InputMethod::Vni;
    let mut bad = Vec::new();
    for s in generate(true) {
        let keys = keys_for(&s, Order::Canonical, vni).unwrap();
        let chars: Vec<char> = s.text.chars().collect();
        for k in 1..=chars.len() {
            let mut e = Engine::new(c.clone());
            for ch in keys.chars() {
                e.process(KeyInput::new(ch));
            }
            for _ in 0..k {
                e.backspace();
            }
            let expect: String = chars[..chars.len() - k].iter().collect();
            if e.composing() != expect {
                bad.push(format!(
                    "{} ⌫×{k} → {:?}, cần {expect:?}",
                    s.text,
                    e.composing()
                ));
                continue;
            }
            // gõ lại các ký tự đã xoá
            for &ch in &chars[chars.len() - k..] {
                let (b, m, t, up) = decompose(ch).unwrap();
                let base = if up { b.to_ascii_uppercase() } else { b };
                // vần `oo` (Telex): gõ lại chữ o thứ hai cần `oo` (o o → ô, o → huỷ)
                let prev_plain_o = e
                    .composing()
                    .chars()
                    .last()
                    .and_then(decompose)
                    .is_some_and(|d| d.0 == 'o' && d.1 == phimviet_core::chars::Mark::None);
                if !vni && b == 'o' && m == phimviet_core::chars::Mark::None && prev_plain_o {
                    e.process(KeyInput::new(base));
                }
                e.process(KeyInput::new(base));
                let mk = match (m, vni) {
                    (phimviet_core::chars::Mark::None, _) => None,
                    (phimviet_core::chars::Mark::Circumflex, false) => Some(b),
                    (phimviet_core::chars::Mark::Circumflex, true) => Some('6'),
                    (phimviet_core::chars::Mark::Horn, true) => Some('7'),
                    (phimviet_core::chars::Mark::Breve, true) => Some('8'),
                    (phimviet_core::chars::Mark::Stroke, true) => Some('9'),
                    (phimviet_core::chars::Mark::Stroke, false) => Some('d'),
                    (_, false) => Some('w'),
                };
                // `oo` (xoong): gõ lại chữ o thứ hai không cần phím dấu
                if let Some(mk) = mk {
                    e.process(KeyInput::new(mk));
                }
                if t != phimviet_core::chars::Tone::None {
                    let tk = match t {
                        phimviet_core::chars::Tone::Acute => {
                            if vni {
                                '1'
                            } else {
                                's'
                            }
                        }
                        phimviet_core::chars::Tone::Grave => {
                            if vni {
                                '2'
                            } else {
                                'f'
                            }
                        }
                        phimviet_core::chars::Tone::Hook => {
                            if vni {
                                '3'
                            } else {
                                'r'
                            }
                        }
                        phimviet_core::chars::Tone::Tilde => {
                            if vni {
                                '4'
                            } else {
                                'x'
                            }
                        }
                        _ => {
                            if vni {
                                '5'
                            } else {
                                'j'
                            }
                        }
                    };
                    e.process(KeyInput::new(tk));
                }
            }
            if e.composing() != s.text {
                bad.push(format!("{} ⌫×{k} rồi gõ lại → {:?}", s.text, e.composing()));
            }
        }
    }
    if !bad.is_empty() {
        let n = bad.len();
        panic!("{n} lỗi:\n{}", bad[..n.min(40)].join("\n"));
    }
}

#[test]
fn backspace_roundtrip_telex() {
    backspace_roundtrip(&telex());
}

#[test]
fn backspace_roundtrip_vni() {
    backspace_roundtrip(&vni());
}

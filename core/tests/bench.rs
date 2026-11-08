//! Benchmark đơn giản: `cargo test --release -p phimviet-core --test bench -- --ignored bench --nocapture`

mod common;
use common::*;
use phimviet_core::{Engine, KeyInput};
use std::time::Instant;

const PARAGRAPH: &str = "Tieengs Vieejt laf ngoon nguwx cuar nguwowif Vieejt vaf laf ngoon nguwx \
chinhs thuwcs taij Vieejt Nam. Ddaay laf tieengs mej ddeer cuar khoangr 85% daan cuw Vieejt Nam \
cungf vowis hown 4 trieeuj nguwowif Vieejt hari ngoaij. Khi gox nhanh nguwowif dungf thuwowngf \
ddatwj daaus owr cuoois tuwf nhuw toans, hoafng, khuyeechs, nguyeenx, quyeenr, giuwax, thuowr.";

#[test]
#[ignore]
fn bench() {
    let c = telex();
    let mut e = Engine::new(c);
    let keys: Vec<char> = PARAGRAPH.chars().collect();
    let rounds = 2_000;
    // làm nóng
    for &k in &keys {
        e.process(KeyInput::new(k));
    }
    let start = Instant::now();
    let mut n = 0u64;
    for _ in 0..rounds {
        for &k in &keys {
            std::hint::black_box(e.process(KeyInput::new(k)));
            n += 1;
        }
    }
    let per_key = start.elapsed().as_nanos() as f64 / n as f64;
    println!(
        "bench: {n} phím, trung bình {:.2} µs/phím",
        per_key / 1000.0
    );
    // trường hợp xấu: từ dài sát ngưỡng đóng băng
    let start = Instant::now();
    let mut m = 0u64;
    for _ in 0..200 {
        let mut e = Engine::new(telex());
        for _ in 0..63 {
            std::hint::black_box(e.process(KeyInput::new('a')));
            m += 1;
        }
    }
    let worst = start.elapsed().as_nanos() as f64 / m as f64;
    println!("bench (từ 63 phím 'a'): {:.2} µs/phím", worst / 1000.0);
    assert!(per_key < 50_000.0, "chậm hơn 50 µs/phím");
}

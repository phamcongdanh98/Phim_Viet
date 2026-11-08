//! `render(raw, config)`: hàm thuần tính chữ hiển thị từ dãy phím thô. Xem ENGINE_RULES §4, §6.

use crate::chars::{Letter, Mark, Tone};
use crate::config::{Config, InputMethod, ToneStyle};
use crate::syllable::{has_vowel, is_valid_full, is_valid_prefix, split, tone_position};
use crate::{telex, vni, KeyInput};

/// Tác dụng của một phím theo kiểu gõ.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub(crate) enum Action {
    Letter,
    Tone(Tone),
    ClearTone,
    /// `Some(b)`: chỉ chữ gốc `b` (Telex); `None`: bất kỳ `a e o` (VNI `6`).
    Circumflex(Option<char>),
    /// Telex `w`: móc hoặc trăng; `insert_u`: chèn `ư` nếu không có gì để biến đổi.
    HornBreve {
        insert_u: bool,
    },
    /// VNI `7`
    Horn,
    /// VNI `8`
    Breve,
    /// `đ`
    Stroke,
    /// Telex `[` `]`
    Insert(char, Mark),
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Effect {
    Normal,
    Undo,
}

#[derive(Clone, Default)]
struct State {
    letters: Vec<Letter>,
    tone: Tone,
    disabled: Vec<char>,
    undo_tail: Option<char>,
    /// Phím (chữ thường) ngay trước phím đang xét.
    prev: Option<char>,
}

impl State {
    fn push(&mut self, ch: char) {
        self.letters.push(Letter::plain(ch));
    }

    fn disable(&mut self, lower: char) {
        if !self.disabled.contains(&lower) {
            self.disabled.push(lower);
        }
    }
}

/// Kết quả tính lại một từ.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Rendered {
    /// Chuỗi đang hiển thị.
    pub display: String,
    /// Kết quả áp phím `T` (có thể khác `display` khi không hợp lệ).
    pub transformed: String,
    /// Phím thô nối lại.
    pub raw: String,
    pub prefix_valid: bool,
    pub full_valid: bool,
    /// Đang ở đuôi huỷ tường minh (ENGINE_RULES §6).
    pub explicit_tail: bool,
    /// Từ bị đóng băng sau backspace (không biến đổi nữa).
    pub frozen: bool,
    /// Chữ chốt đã sửa nhẹ (khi `T` không hợp lệ nhưng bản sửa hợp lệ).
    pub committed: Option<String>,
}

fn action_for(lower: char, cfg: &Config) -> Action {
    match cfg.method {
        InputMethod::Vni => vni::action(lower),
        InputMethod::Telex | InputMethod::SimpleTelex => telex::action(lower, cfg),
    }
}

pub(crate) fn render(raw: &[KeyInput], cfg: &Config) -> Rendered {
    let raw_str: String = raw.iter().map(|k| k.ch).collect();
    if raw.first().is_some_and(|k| k.literal) {
        return Rendered {
            display: raw_str.clone(),
            transformed: raw_str.clone(),
            raw: raw_str,
            frozen: true,
            ..Rendered::default()
        };
    }
    let mut st = State {
        letters: Vec::with_capacity(raw.len() + 2),
        ..State::default()
    };
    for k in raw {
        step(&mut st, k.ch, cfg);
    }
    let letters = normalize(&st.letters);
    let tpos = tone_position(&letters, cfg.tone_style == ToneStyle::New);
    let transformed: String = letters
        .iter()
        .enumerate()
        .map(|(i, l)| l.render(if Some(i) == tpos { st.tone } else { Tone::None }))
        .collect();
    // Từ không có nguyên âm (`đ`, `đc`, `đt`): không kiểm tra, không khôi phục.
    let vowelless = !st.letters.iter().any(|l| l.is_vowel());
    let prefix_valid = vowelless || is_valid_prefix(&st.letters);
    let full_valid = vowelless || is_valid_full(&letters, st.tone);
    // Đuôi huỷ chỉ được công nhận khi kết quả sau huỷ là chữ ASCII thuần (`as`, `aa`, `dd`).
    let explicit_tail = st.undo_tail.is_some() && transformed.is_ascii();
    let display = if !cfg.spell_check || prefix_valid || explicit_tail {
        transformed.clone()
    } else {
        raw_str.clone()
    };
    let committed = if full_valid {
        None
    } else {
        commit_fix(&letters, st.tone, cfg.tone_style == ToneStyle::New)
    };
    Rendered {
        display,
        transformed,
        raw: raw_str,
        prefix_valid,
        full_valid,
        explicit_tail,
        frozen: false,
        committed,
    }
}

fn step(st: &mut State, ch: char, cfg: &Config) {
    let lower = ch.to_ascii_lowercase();
    let action = if st.disabled.contains(&lower) {
        Action::Letter
    } else {
        action_for(lower, cfg)
    };
    // Trạng thái trước phím (chỉ cần khi phím có thể là phím huỷ).
    let before = if action == Action::Letter {
        None
    } else {
        Some((st.letters.clone(), st.undo_tail))
    };
    let effect = apply(st, ch, lower, action);
    match effect {
        Effect::Undo => {
            // Huỷ "tường minh" khi biến đổi bị huỷ là chữ Việt hợp lệ, hoặc (tắt kiểm tra âm tiết)
            // khi gõ lặp ngay phím vừa biến đổi (`aaa`, `ss`). `dêlt` + `e` (gõ "delete") không
            // phải huỷ tường minh → khi chốt được khôi phục thành phím thô.
            let shown = match before {
                Some((letters, tail)) => {
                    tail.is_some()
                        || is_valid_prefix(&letters)
                        || (!cfg.spell_check && st.prev == Some(lower))
                }
                None => false,
            };
            st.undo_tail = if shown { Some(lower) } else { None };
        }
        Effect::Normal => {
            if st.undo_tail != Some(lower) {
                st.undo_tail = None;
            }
        }
    }
    st.prev = Some(lower);
}

fn cluster(letters: &[Letter]) -> (usize, usize) {
    let p = split(letters);
    (p.ini, p.vow)
}

fn undo_with_literal(st: &mut State, ch: char, lower: char) -> Effect {
    st.push(ch);
    st.disable(lower);
    Effect::Undo
}

fn apply(st: &mut State, ch: char, lower: char, action: Action) -> Effect {
    match action {
        Action::Letter => {
            st.push(ch);
            Effect::Normal
        }
        Action::Tone(t) => {
            if !has_vowel(&st.letters) {
                st.push(ch);
                Effect::Normal
            } else if st.tone == t {
                st.tone = Tone::None;
                undo_with_literal(st, ch, lower)
            } else {
                st.tone = t;
                Effect::Normal
            }
        }
        Action::ClearTone => {
            if st.tone != Tone::None {
                st.tone = Tone::None;
            } else {
                st.push(ch);
            }
            Effect::Normal
        }
        Action::Circumflex(target) => {
            let (s, e) = cluster(&st.letters);
            let matches = |l: &Letter| match target {
                Some(b) => l.base == b,
                None => matches!(l.base, 'a' | 'e' | 'o'),
            };
            let cands: Vec<usize> = (s..e)
                .rev()
                .filter(|&i| matches(&st.letters[i]) && st.letters[i].mark != Mark::Circumflex)
                .collect();
            let has_circ =
                (s..e).any(|i| matches(&st.letters[i]) && st.letters[i].mark == Mark::Circumflex);
            let choice = cands.iter().copied().find(|&i| {
                let mut t = st.letters.clone();
                t[i].mark = Mark::Circumflex;
                t[i].implicit = false;
                is_valid_prefix(&t)
            });
            if let Some(i) = choice {
                set_mark(&mut st.letters[i], Mark::Circumflex);
                return Effect::Normal;
            }
            let mut appended = st.letters.clone();
            appended.push(Letter::plain(ch));
            if is_valid_prefix(&appended) {
                st.letters = appended;
                Effect::Normal
            } else if has_circ {
                for l in &mut st.letters[s..e] {
                    if matches(l) && l.mark == Mark::Circumflex {
                        l.mark = Mark::None;
                    }
                }
                undo_with_literal(st, ch, lower)
            } else if let Some(&i) = cands.first() {
                set_mark(&mut st.letters[i], Mark::Circumflex);
                Effect::Normal
            } else {
                st.push(ch);
                Effect::Normal
            }
        }
        Action::HornBreve { insert_u } => horn_breve(st, ch, lower, true, true, insert_u),
        Action::Horn => horn_breve(st, ch, lower, true, false, false),
        Action::Breve => horn_breve(st, ch, lower, false, true, false),
        Action::Stroke => {
            if st.letters.first().map(|l| l.base) != Some('d') {
                st.push(ch);
                return Effect::Normal;
            }
            if st.letters[0].mark == Mark::Stroke {
                st.letters[0].mark = Mark::None;
                undo_with_literal(st, ch, lower)
            } else {
                st.letters[0].mark = Mark::Stroke;
                Effect::Normal
            }
        }
        Action::Insert(base, mark) => {
            st.letters.push(Letter {
                base,
                mark,
                upper: false,
                implicit: false,
                inserted: true,
            });
            Effect::Normal
        }
    }
}

fn set_mark(l: &mut Letter, m: Mark) {
    l.mark = m;
    l.implicit = false;
}

/// Một phương án áp dấu: danh sách (vị trí, dấu, ngầm định?).
type Candidate = Vec<(usize, Mark, bool)>;

fn horn_breve(
    st: &mut State,
    ch: char,
    lower: char,
    horn: bool,
    breve: bool,
    insert_u: bool,
) -> Effect {
    let (s, e) = cluster(&st.letters);
    let l = &st.letters;
    let mut cands: Vec<Candidate> = Vec::new();
    if horn {
        for i in s..e.saturating_sub(1) {
            if l[i].base == 'u' && l[i + 1].base == 'o' {
                let implicit = l[i].mark != Mark::Horn || l[i].implicit;
                cands.push(vec![(i, Mark::Horn, implicit), (i + 1, Mark::Horn, false)]);
            }
        }
        for i in (s..e).rev() {
            if l[i].base == 'o' {
                cands.push(vec![(i, Mark::Horn, false)]);
            }
        }
        for (i, x) in l.iter().enumerate().take(e).skip(s) {
            if x.base == 'u' {
                cands.push(vec![(i, Mark::Horn, false)]);
            }
        }
    }
    if breve {
        for (i, x) in l.iter().enumerate().take(e).skip(s) {
            if x.base == 'a' {
                cands.push(vec![(i, Mark::Breve, false)]);
            }
        }
    }
    let changes = |c: &Candidate| c.iter().any(|&(i, m, _)| l[i].mark != m);
    let applicable: Vec<&Candidate> = cands.iter().filter(|c| changes(c)).collect();
    let apply_to = |letters: &mut [Letter], c: &Candidate| {
        for &(i, m, imp) in c {
            if letters[i].mark != m {
                letters[i].mark = m;
                letters[i].implicit = imp;
            } else if !imp {
                letters[i].implicit = false;
            }
        }
    };
    let choice = applicable.iter().find(|c| {
        let mut t = st.letters.clone();
        apply_to(&mut t, c);
        is_valid_prefix(&t)
    });
    if let Some(c) = choice {
        let c = (*c).clone();
        apply_to(&mut st.letters, &c);
        return Effect::Normal;
    }
    let ours = |l: &Letter| (horn && l.mark == Mark::Horn) || (breve && l.mark == Mark::Breve);
    let has_ours = st.letters[s..e].iter().any(ours);
    if has_ours {
        // Huỷ: bỏ dấu do phím này tạo, bỏ `ư` đã chèn, thêm phím như chữ thường.
        let mut out = Vec::with_capacity(st.letters.len());
        let mut removed_upper = None;
        for (i, l) in st.letters.iter().enumerate() {
            if i >= s && i < e && ours(l) {
                if l.inserted {
                    removed_upper = Some(l.upper);
                    continue;
                }
                let mut l = *l;
                l.mark = Mark::None;
                l.implicit = false;
                out.push(l);
            } else {
                out.push(*l);
            }
        }
        st.letters = out;
        // `Ww` → `W`: chữ còn lại mang hoa/thường của phím `w` đầu tiên (đã tạo `Ư`).
        let lit = match removed_upper {
            Some(true) => ch.to_ascii_uppercase(),
            Some(false) => ch.to_ascii_lowercase(),
            None => ch,
        };
        return undo_with_literal(st, lit, lower);
    }
    if let Some(c) = applicable.first() {
        let c = (*c).clone();
        apply_to(&mut st.letters, &c);
        return Effect::Normal;
    }
    if insert_u {
        st.letters.push(Letter {
            base: 'u',
            mark: Mark::Horn,
            upper: ch.is_uppercase(),
            implicit: false,
            inserted: true,
        });
    } else {
        st.push(ch);
    }
    Effect::Normal
}

/// Chuẩn hoá cặp `uo` có móc (ENGINE_RULES §4.7):
/// - `ư` + `o` + chữ theo sau → `ươ` (`dduwocj` → `được`, `truwongf` → `trường`);
/// - `ươ` đứng cuối từ với móc `u` ngầm định → `uơ` (`thuowr` → `thuở`). Móc tường minh
///   (`thuwowr`) chỉ được chuẩn hoá lúc chốt — xem `commit_fix`.
fn normalize(letters: &[Letter]) -> Vec<Letter> {
    let mut out = letters.to_vec();
    let n = out.len();
    for i in 0..n.saturating_sub(2) {
        if out[i].base == 'u'
            && out[i].mark == Mark::Horn
            && out[i + 1].base == 'o'
            && out[i + 1].mark == Mark::None
        {
            out[i + 1].mark = Mark::Horn;
        }
    }
    if n >= 2 {
        let (u, o) = (out[n - 2], out[n - 1]);
        if u.base == 'u'
            && u.mark == Mark::Horn
            && u.implicit
            && o.base == 'o'
            && o.mark == Mark::Horn
        {
            out[n - 2].mark = Mark::None;
            out[n - 2].implicit = false;
        }
    }
    out
}

/// Chữ chốt thay thế khi `T` không hợp lệ nhưng sửa nhẹ thì hợp lệ:
/// `ươ` cuối từ có móc tường minh sau `h th kh` → `uơ` (`thuwowr` → `thuở`).
fn commit_fix(letters: &[Letter], tone: Tone, new_style: bool) -> Option<String> {
    let n = letters.len();
    if n < 3 {
        return None;
    }
    let (u, o) = (letters[n - 2], letters[n - 1]);
    if !(u.base == 'u' && u.mark == Mark::Horn && o.base == 'o' && o.mark == Mark::Horn) {
        return None;
    }
    let mut fixed = letters.to_vec();
    fixed[n - 2].mark = Mark::None;
    if !is_valid_full(&fixed, tone) {
        return None;
    }
    let tpos = tone_position(&fixed, new_style);
    Some(
        fixed
            .iter()
            .enumerate()
            .map(|(i, l)| l.render(if Some(i) == tpos { tone } else { Tone::None }))
            .collect(),
    )
}

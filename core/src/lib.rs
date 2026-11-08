//! # Phím Việt — lõi engine
//!
//! Engine thuần, tất định, không phụ thuộc hệ điều hành. Mỗi từ đang gõ lưu dãy phím thô;
//! mỗi phím mới tính lại toàn bộ chữ hiển thị bằng hàm thuần `render(raw, config)`.
//! Engine trả **chuỗi hiển thị mới của từ**, không trả số backspace — shell tự tính phần khác.
//!
//! ```
//! use phimviet_core::{Engine, Config, KeyInput, Output, Boundary};
//! let mut e = Engine::new(Config::default());
//! for c in "vieejt".chars() { e.process(KeyInput::new(c)); }
//! assert_eq!(e.composing(), "việt");
//! assert_eq!(e.commit(Boundary::Space), Output::Commit { text: "việt".into(), pass_through: true });
//! ```

pub mod chars;
mod compose;
pub mod config;
pub mod json;
pub mod macros;
mod restore;
pub mod syllable;
mod telex;
mod vni;

pub use compose::Rendered;
pub use config::{Config, InputMethod, ToneStyle};

/// Độ dài raw tối đa trước khi từ bị đóng băng (chống phím lặp dài).
const MAX_RAW: usize = 64;

/// Một phím chữ gửi vào engine.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct KeyInput {
    pub ch: char,
    pub(crate) literal: bool,
}

impl KeyInput {
    pub fn new(ch: char) -> Self {
        KeyInput { ch, literal: false }
    }

    /// `caps`: Caps Lock đang bật → chữ cái được viết hoa. `shift` đã phản ánh trong `ch`.
    pub fn with_flags(ch: char, _shift: bool, caps: bool) -> Self {
        let ch = if caps && ch.is_ascii_lowercase() {
            ch.to_ascii_uppercase()
        } else {
            ch
        };
        KeyInput { ch, literal: false }
    }
}

/// Lý do kết thúc từ.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Boundary {
    Space,
    Enter,
    Tab,
    /// Dấu câu / ký hiệu / chữ số (Telex) — ký tự sẽ được đưa cho ứng dụng.
    Char(char),
    /// Click chuột.
    Mouse,
    /// Đổi ứng dụng / ô nhập.
    Focus,
    /// Chốt theo yêu cầu khác (phím tắt ⌘…, mũi tên…).
    Other,
}

impl Boundary {
    pub fn from_char(c: char) -> Boundary {
        match c {
            ' ' => Boundary::Space,
            '\r' | '\n' => Boundary::Enter,
            '\t' => Boundary::Tab,
            c => Boundary::Char(c),
        }
    }

    /// Kết thúc bằng một phím được đưa tiếp cho ứng dụng.
    pub fn is_key(self) -> bool {
        matches!(
            self,
            Boundary::Space | Boundary::Enter | Boundary::Tab | Boundary::Char(_)
        )
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Output {
    /// Engine không xử lý (không có từ dở) — đưa phím cho ứng dụng.
    Unchanged,
    /// Phím đã được nhận; chữ hiển thị của từ hiện tại là chuỗi này (có thể rỗng).
    Composing(String),
    /// Từ kết thúc: thay chữ hiển thị bằng `text`; `pass_through` → đưa phím cho ứng dụng.
    Commit { text: String, pass_through: bool },
}

pub struct Engine {
    config: Config,
    raw: Vec<KeyInput>,
    last: Rendered,
}

impl Engine {
    pub fn new(config: Config) -> Self {
        Engine {
            config,
            raw: Vec::with_capacity(MAX_RAW),
            last: Rendered::default(),
        }
    }

    pub fn config(&self) -> &Config {
        &self.config
    }

    /// Đổi cấu hình; từ đang gõ được tính lại theo cấu hình mới.
    pub fn set_config(&mut self, config: Config) {
        self.config = config;
        if !self.raw.is_empty() {
            self.rerender();
        }
    }

    pub fn composing(&self) -> &str {
        &self.last.display
    }

    pub fn is_composing(&self) -> bool {
        !self.raw.is_empty()
    }

    /// Phím thô của từ hiện tại.
    pub fn raw_text(&self) -> &str {
        &self.last.raw
    }

    /// Chi tiết lần tính gần nhất (để chẩn đoán / test).
    pub fn rendered(&self) -> &Rendered {
        &self.last
    }

    fn rerender(&mut self) {
        self.last = compose::render(&self.raw, &self.config);
    }

    fn is_word_key(&self, ch: char) -> bool {
        match self.config.method {
            InputMethod::Vni => vni::is_word_key(ch, !self.raw.is_empty()),
            _ => telex::is_word_key(ch, &self.config),
        }
    }

    /// Ký tự có thể là một phím trong từ (khi đang gõ dở).
    fn is_key_char(&self, ch: char) -> bool {
        match self.config.method {
            InputMethod::Vni => vni::is_word_key(ch, true),
            _ => telex::is_word_key(ch, &self.config),
        }
    }

    pub fn process(&mut self, key: KeyInput) -> Output {
        if !self.is_word_key(key.ch) {
            return self.commit(Boundary::from_char(key.ch));
        }
        if self.raw.len() >= MAX_RAW && !self.last.frozen {
            self.raw = restore::frozen_raw(&self.last.display);
        }
        self.raw.push(KeyInput::new(key.ch));
        self.rerender();
        Output::Composing(self.last.display.clone())
    }

    /// Xoá một ký tự hiển thị cuối và dựng lại raw tương ứng (ENGINE_RULES §8).
    pub fn backspace(&mut self) -> Output {
        if self.raw.is_empty() {
            return Output::Unchanged;
        }
        let mut target = self.last.display.clone();
        target.pop();
        if target.is_empty() {
            self.reset();
            return Output::Composing(String::new());
        }
        let candidates = [
            if self.last.frozen {
                None
            } else {
                restore::canonical_raw(&target, &self.config)
            },
            if self.last.frozen || !target.chars().all(|c| self.is_key_char(c)) {
                None
            } else {
                Some(restore::plain_raw(&target))
            },
        ];
        let mut chosen = None;
        for raw in candidates.into_iter().flatten() {
            let r = compose::render(&raw, &self.config);
            if r.display == target {
                chosen = Some((raw, r));
                break;
            }
        }
        match chosen {
            Some((raw, r)) => {
                self.raw = raw;
                self.last = r;
            }
            None => {
                self.raw = restore::frozen_raw(&target);
                self.rerender();
            }
        }
        Output::Composing(self.last.display.clone())
    }

    /// Kết thúc từ: gõ tắt, tự khôi phục tiếng Anh (ENGINE_RULES §7), rồi reset.
    pub fn commit(&mut self, boundary: Boundary) -> Output {
        if self.raw.is_empty() {
            return Output::Unchanged;
        }
        let text = self.final_text(boundary);
        self.reset();
        Output::Commit {
            text,
            pass_through: boundary.is_key(),
        }
    }

    /// Chữ sẽ được chốt nếu kết thúc từ bằng `boundary` (không đổi trạng thái).
    pub fn final_text(&self, boundary: Boundary) -> String {
        let r = &self.last;
        if boundary.is_key() && self.config.macros_enabled && !self.config.macros.is_empty() {
            let m = &self.config.macros;
            if let Some(x) = macros::lookup(m, &r.raw)
                .or_else(|| macros::lookup(m, &r.display))
                .or_else(|| macros::lookup(m, &r.transformed))
            {
                return x;
            }
        }
        if let Some(fixed) = &r.committed {
            return fixed.clone();
        }
        if !r.frozen && self.config.auto_restore && !r.full_valid && !r.explicit_tail {
            return r.raw.clone();
        }
        r.display.clone()
    }

    /// ESC: trả lại đúng phím thô đã gõ và kết thúc từ.
    pub fn restore_raw(&mut self) -> Output {
        if self.raw.is_empty() {
            return Output::Unchanged;
        }
        let text = self.last.raw.clone();
        self.reset();
        Output::Commit {
            text,
            pass_through: false,
        }
    }

    pub fn reset(&mut self) {
        self.raw.clear();
        self.last = Rendered::default();
    }
}

/// Tiện ích: gõ cả chuỗi phím vào một engine mới, trả chữ hiển thị (không chốt).
pub fn render_str(keys: &str, config: &Config) -> String {
    let mut e = Engine::new(config.clone());
    for c in keys.chars() {
        e.process(KeyInput::new(c));
    }
    e.composing().to_string()
}

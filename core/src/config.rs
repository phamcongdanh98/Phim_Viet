//! Cấu hình engine + đọc/ghi JSON.

use crate::json::{self, Json};

#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
pub enum InputMethod {
    #[default]
    Telex,
    Vni,
    SimpleTelex,
}

#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
pub enum ToneStyle {
    /// hoà, khoẻ, thuỷ
    #[default]
    New,
    /// hòa, khỏe, thủy
    Old,
}

#[derive(Clone, PartialEq, Eq, Debug)]
pub struct Config {
    pub method: InputMethod,
    pub tone_style: ToneStyle,
    /// Kiểm tra âm tiết hợp lệ khi đang gõ (không hợp lệ → hiện phím thô).
    pub spell_check: bool,
    /// Tự khôi phục phím thô khi chốt từ không hợp lệ.
    pub auto_restore: bool,
    /// Telex: `w` đứng riêng → `ư`.
    pub w_as_u: bool,
    /// Telex: `[` → `ơ`, `]` → `ư`.
    pub brackets: bool,
    pub macros_enabled: bool,
    /// (từ tắt, cụm thay thế)
    pub macros: Vec<(String, String)>,
}

impl Default for Config {
    fn default() -> Self {
        Config {
            method: InputMethod::Telex,
            tone_style: ToneStyle::New,
            spell_check: true,
            auto_restore: true,
            w_as_u: true,
            brackets: false,
            macros_enabled: true,
            macros: Vec::new(),
        }
    }
}

impl Config {
    /// Đọc cấu hình từ JSON. Khoá thiếu → giá trị mặc định; khoá lạ bị bỏ qua.
    ///
    /// ```json
    /// {"method":"telex","tone_style":"new","spell_check":true,"auto_restore":true,
    ///  "w_as_u":true,"brackets":false,"macros_enabled":true,"macros":{"vn":"Việt Nam"}}
    /// ```
    pub fn from_json(s: &str) -> Result<Config, String> {
        let v = json::parse(s)?;
        let Json::Obj(fields) = v else {
            return Err("config phải là object".into());
        };
        let mut c = Config::default();
        for (k, v) in fields {
            match (k.as_str(), v) {
                ("method", Json::Str(m)) => {
                    c.method = match m.as_str() {
                        "telex" => InputMethod::Telex,
                        "vni" => InputMethod::Vni,
                        "simple_telex" => InputMethod::SimpleTelex,
                        _ => return Err(format!("method không hợp lệ: {m}")),
                    }
                }
                ("tone_style", Json::Str(m)) => {
                    c.tone_style = match m.as_str() {
                        "new" => ToneStyle::New,
                        "old" => ToneStyle::Old,
                        _ => return Err(format!("tone_style không hợp lệ: {m}")),
                    }
                }
                ("spell_check", Json::Bool(b)) => c.spell_check = b,
                ("auto_restore", Json::Bool(b)) => c.auto_restore = b,
                ("w_as_u", Json::Bool(b)) => c.w_as_u = b,
                ("brackets", Json::Bool(b)) => c.brackets = b,
                ("macros_enabled", Json::Bool(b)) => c.macros_enabled = b,
                ("macros", m) => c.macros = parse_macros(m)?,
                _ => {}
            }
        }
        Ok(c)
    }

    pub fn to_json(&self) -> String {
        let method = match self.method {
            InputMethod::Telex => "telex",
            InputMethod::Vni => "vni",
            InputMethod::SimpleTelex => "simple_telex",
        };
        let style = match self.tone_style {
            ToneStyle::New => "new",
            ToneStyle::Old => "old",
        };
        let mut s = format!(
            "{{\"method\":\"{method}\",\"tone_style\":\"{style}\",\"spell_check\":{},\"auto_restore\":{},\"w_as_u\":{},\"brackets\":{},\"macros_enabled\":{},\"macros\":{{",
            self.spell_check, self.auto_restore, self.w_as_u, self.brackets, self.macros_enabled
        );
        for (i, (k, v)) in self.macros.iter().enumerate() {
            if i > 0 {
                s.push(',');
            }
            s.push_str(&json::quote(k));
            s.push(':');
            s.push_str(&json::quote(v));
        }
        s.push_str("}}");
        s
    }
}

/// Nhận `{"vn":"Việt Nam"}` hoặc `[{"key":"vn","value":"Việt Nam"}]`.
pub fn parse_macros(v: Json) -> Result<Vec<(String, String)>, String> {
    let mut out = Vec::new();
    match v {
        Json::Obj(fields) => {
            for (k, v) in fields {
                if let Json::Str(s) = v {
                    push_macro(&mut out, k, s);
                }
            }
        }
        Json::Arr(items) => {
            for it in items {
                if let Json::Obj(f) = it {
                    let mut key = None;
                    let mut val = None;
                    for (k, v) in f {
                        match (k.as_str(), v) {
                            ("key", Json::Str(s)) => key = Some(s),
                            ("value", Json::Str(s)) => val = Some(s),
                            _ => {}
                        }
                    }
                    if let (Some(k), Some(v)) = (key, val) {
                        push_macro(&mut out, k, v);
                    }
                }
            }
        }
        Json::Null => {}
        _ => return Err("macros phải là object hoặc mảng".into()),
    }
    Ok(out)
}

fn push_macro(out: &mut Vec<(String, String)>, k: String, v: String) {
    // Giá trị dán từ nguồn NFD vẫn phải xuất ra NFC; từ tắt NFD vẫn phải khớp.
    let k = crate::chars::nfc(k.trim());
    let v = crate::chars::nfc(&v);
    if k.is_empty() || k.chars().count() > 64 || v.chars().count() > 4096 {
        return;
    }
    out.retain(|(e, _)| e.to_lowercase() != k.to_lowercase());
    out.push((k, v));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn json_roundtrip() {
        let mut c = Config {
            method: InputMethod::Vni,
            tone_style: ToneStyle::Old,
            spell_check: false,
            ..Config::default()
        };
        c.macros.push(("vn".into(), "Việt \"Nam\"\n".into()));
        let back = Config::from_json(&c.to_json()).unwrap();
        assert_eq!(back, c);
    }

    #[test]
    fn macros_array_form() {
        let c = Config::from_json(r#"{"macros":[{"key":"hn","value":"Hà Nội"}]}"#).unwrap();
        assert_eq!(c.macros, vec![("hn".to_string(), "Hà Nội".to_string())]);
        assert!(Config::from_json("[1]").is_err());
        assert!(Config::from_json(r#"{"method":"xyz"}"#).is_err());
    }
}

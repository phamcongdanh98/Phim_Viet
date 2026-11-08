//! Bộ đọc JSON tối giản (0 dependency) đủ cho cấu hình và bảng gõ tắt.

#[derive(Clone, Debug, PartialEq)]
pub enum Json {
    Null,
    Bool(bool),
    Num(f64),
    Str(String),
    Arr(Vec<Json>),
    Obj(Vec<(String, Json)>),
}

const MAX_DEPTH: usize = 32;
const MAX_LEN: usize = 4 * 1024 * 1024;

pub fn parse(s: &str) -> Result<Json, String> {
    if s.len() > MAX_LEN {
        return Err("JSON quá lớn".into());
    }
    let mut p = Parser {
        b: s.as_bytes(),
        i: 0,
    };
    p.ws();
    let v = p.value(0)?;
    p.ws();
    if p.i != p.b.len() {
        return Err(format!("thừa ký tự ở vị trí {}", p.i));
    }
    Ok(v)
}

/// Bọc chuỗi thành literal JSON.
pub fn quote(s: &str) -> String {
    let mut o = String::with_capacity(s.len() + 2);
    o.push('"');
    for c in s.chars() {
        match c {
            '"' => o.push_str("\\\""),
            '\\' => o.push_str("\\\\"),
            '\n' => o.push_str("\\n"),
            '\r' => o.push_str("\\r"),
            '\t' => o.push_str("\\t"),
            c if (c as u32) < 0x20 => o.push_str(&format!("\\u{:04x}", c as u32)),
            c => o.push(c),
        }
    }
    o.push('"');
    o
}

struct Parser<'a> {
    b: &'a [u8],
    i: usize,
}

impl Parser<'_> {
    fn ws(&mut self) {
        while self.i < self.b.len() && matches!(self.b[self.i], b' ' | b'\t' | b'\n' | b'\r') {
            self.i += 1;
        }
    }

    fn peek(&self) -> Option<u8> {
        self.b.get(self.i).copied()
    }

    fn expect(&mut self, c: u8) -> Result<(), String> {
        if self.peek() == Some(c) {
            self.i += 1;
            Ok(())
        } else {
            Err(format!("cần '{}' ở vị trí {}", c as char, self.i))
        }
    }

    fn lit(&mut self, word: &str, v: Json) -> Result<Json, String> {
        if self.b[self.i..].starts_with(word.as_bytes()) {
            self.i += word.len();
            Ok(v)
        } else {
            Err(format!("giá trị lạ ở vị trí {}", self.i))
        }
    }

    fn value(&mut self, depth: usize) -> Result<Json, String> {
        if depth > MAX_DEPTH {
            return Err("JSON lồng quá sâu".into());
        }
        match self.peek() {
            Some(b'{') => self.object(depth),
            Some(b'[') => self.array(depth),
            Some(b'"') => Ok(Json::Str(self.string()?)),
            Some(b't') => self.lit("true", Json::Bool(true)),
            Some(b'f') => self.lit("false", Json::Bool(false)),
            Some(b'n') => self.lit("null", Json::Null),
            Some(c) if c == b'-' || c.is_ascii_digit() => self.number(),
            _ => Err(format!("giá trị lạ ở vị trí {}", self.i)),
        }
    }

    fn object(&mut self, depth: usize) -> Result<Json, String> {
        self.expect(b'{')?;
        let mut out = Vec::new();
        self.ws();
        if self.peek() == Some(b'}') {
            self.i += 1;
            return Ok(Json::Obj(out));
        }
        loop {
            self.ws();
            let k = self.string()?;
            self.ws();
            self.expect(b':')?;
            self.ws();
            let v = self.value(depth + 1)?;
            out.push((k, v));
            self.ws();
            match self.peek() {
                Some(b',') => self.i += 1,
                Some(b'}') => {
                    self.i += 1;
                    return Ok(Json::Obj(out));
                }
                _ => return Err(format!("cần ',' hoặc '}}' ở vị trí {}", self.i)),
            }
        }
    }

    fn array(&mut self, depth: usize) -> Result<Json, String> {
        self.expect(b'[')?;
        let mut out = Vec::new();
        self.ws();
        if self.peek() == Some(b']') {
            self.i += 1;
            return Ok(Json::Arr(out));
        }
        loop {
            self.ws();
            out.push(self.value(depth + 1)?);
            self.ws();
            match self.peek() {
                Some(b',') => self.i += 1,
                Some(b']') => {
                    self.i += 1;
                    return Ok(Json::Arr(out));
                }
                _ => return Err(format!("cần ',' hoặc ']' ở vị trí {}", self.i)),
            }
        }
    }

    fn hex4(&mut self) -> Result<u32, String> {
        let h = self
            .b
            .get(self.i..self.i + 4)
            .ok_or_else(|| "\\u thiếu ký tự".to_string())?;
        let s = std::str::from_utf8(h).map_err(|_| "\\u lỗi".to_string())?;
        let v = u32::from_str_radix(s, 16).map_err(|_| "\\u lỗi".to_string())?;
        self.i += 4;
        Ok(v)
    }

    fn string(&mut self) -> Result<String, String> {
        self.expect(b'"')?;
        let mut out = Vec::<u8>::new();
        loop {
            let Some(c) = self.peek() else {
                return Err("chuỗi chưa đóng".into());
            };
            self.i += 1;
            match c {
                b'"' => break,
                b'\\' => {
                    let Some(e) = self.peek() else {
                        return Err("chuỗi chưa đóng".into());
                    };
                    self.i += 1;
                    let ch = match e {
                        b'"' => '"',
                        b'\\' => '\\',
                        b'/' => '/',
                        b'b' => '\u{8}',
                        b'f' => '\u{c}',
                        b'n' => '\n',
                        b'r' => '\r',
                        b't' => '\t',
                        b'u' => {
                            let hi = self.hex4()?;
                            let code = if (0xD800..0xDC00).contains(&hi) {
                                if self.b.get(self.i..self.i + 2) != Some(b"\\u") {
                                    return Err("thiếu surrogate thấp".into());
                                }
                                self.i += 2;
                                let lo = self.hex4()?;
                                if !(0xDC00..0xE000).contains(&lo) {
                                    return Err("surrogate thấp sai".into());
                                }
                                0x10000 + ((hi - 0xD800) << 10) + (lo - 0xDC00)
                            } else {
                                hi
                            };
                            char::from_u32(code).ok_or_else(|| "mã \\u sai".to_string())?
                        }
                        _ => return Err("escape lạ".into()),
                    };
                    let mut buf = [0u8; 4];
                    out.extend_from_slice(ch.encode_utf8(&mut buf).as_bytes());
                }
                c if c < 0x20 => return Err("ký tự điều khiển trong chuỗi".into()),
                c => out.push(c),
            }
        }
        String::from_utf8(out).map_err(|_| "UTF-8 không hợp lệ".into())
    }

    fn number(&mut self) -> Result<Json, String> {
        let start = self.i;
        while self.i < self.b.len()
            && matches!(
                self.b[self.i],
                b'-' | b'+' | b'.' | b'e' | b'E' | b'0'..=b'9'
            )
        {
            self.i += 1;
        }
        let s = std::str::from_utf8(&self.b[start..self.i]).map_err(|_| "số lỗi".to_string())?;
        s.parse::<f64>()
            .map(Json::Num)
            .map_err(|_| format!("số lỗi: {s}"))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_basic() {
        let v = parse(r#" {"a": [1, -2.5e1, true, false, null], "b": "x\"á😀"} "#).unwrap();
        let Json::Obj(f) = v else { panic!() };
        assert_eq!(f[1].1, Json::Str("x\"á😀".into()));
        assert!(parse("{").is_err());
        assert!(parse("[1,]").is_err());
        assert!(parse("\"abc").is_err());
        assert!(parse(&"[".repeat(100)).is_err());
        assert_eq!(
            parse(&quote("a\"b\n\u{1}")).unwrap(),
            Json::Str("a\"b\n\u{1}".into())
        );
    }
}

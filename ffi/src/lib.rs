//! C ABI cho lõi Phím Việt. Header: `ffi/include/phimviet.h`.
//!
//! Quy ước bộ nhớ: mọi `char *` trả về do Rust cấp phát (UTF-8, kết thúc NUL);
//! phía gọi giải phóng **đúng một lần** bằng `pv_string_free`. Không panic nào được
//! đi xuyên qua ranh giới FFI (`catch_unwind`); nếu engine panic, nó được reset và
//! hàm trả về kết quả "không xử lý".

use phimviet_core::{Boundary, Config, Engine, KeyInput, Output};
use std::ffi::{c_char, CStr, CString};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::ptr;

/// Engine mờ (opaque) cho C.
pub struct PvEngine {
    engine: Engine,
}

pub const PV_UNCHANGED: i32 = 0;
pub const PV_COMPOSING: i32 = 1;
pub const PV_COMMIT: i32 = 2;

pub const PV_FLAG_SHIFT: u32 = 1;
pub const PV_FLAG_CAPS: u32 = 2;

pub const PV_BOUNDARY_SPACE: i32 = 0;
pub const PV_BOUNDARY_ENTER: i32 = 1;
pub const PV_BOUNDARY_TAB: i32 = 2;
pub const PV_BOUNDARY_CHAR: i32 = 3;
pub const PV_BOUNDARY_MOUSE: i32 = 4;
pub const PV_BOUNDARY_FOCUS: i32 = 5;
pub const PV_BOUNDARY_OTHER: i32 = 6;

#[repr(C)]
pub struct PvResult {
    /// `PV_UNCHANGED` / `PV_COMPOSING` / `PV_COMMIT`
    pub kind: i32,
    /// Chữ hiển thị mới (COMPOSING) hoặc chữ chốt (COMMIT); NULL khi UNCHANGED.
    pub text: *mut c_char,
    /// COMMIT: phím kích hoạt cần được đưa tiếp cho ứng dụng.
    pub pass_through: bool,
}

impl PvResult {
    fn unchanged() -> Self {
        PvResult {
            kind: PV_UNCHANGED,
            text: ptr::null_mut(),
            pass_through: true,
        }
    }
}

fn to_c(s: String) -> *mut c_char {
    // Chuỗi của engine không chứa NUL; nếu có thì bỏ NUL đi thay vì thất bại.
    let s = if s.contains('\0') {
        s.replace('\0', "")
    } else {
        s
    };
    CString::new(s)
        .map(CString::into_raw)
        .unwrap_or(ptr::null_mut())
}

fn convert(o: Output) -> PvResult {
    match o {
        Output::Unchanged => PvResult::unchanged(),
        Output::Composing(s) => PvResult {
            kind: PV_COMPOSING,
            text: to_c(s),
            pass_through: false,
        },
        Output::Commit { text, pass_through } => PvResult {
            kind: PV_COMMIT,
            text: to_c(text),
            pass_through,
        },
    }
}

/// Chạy `f` với engine, bắt panic; panic → reset engine, trả UNCHANGED.
fn with_engine(e: *mut PvEngine, f: impl FnOnce(&mut Engine) -> Output) -> PvResult {
    if e.is_null() {
        return PvResult::unchanged();
    }
    // SAFETY: con trỏ do `pv_engine_new` cấp và chưa bị `pv_engine_free`; phía gọi
    // bảo đảm không dùng đồng thời từ nhiều luồng.
    let pv = unsafe { &mut *e };
    match catch_unwind(AssertUnwindSafe(|| f(&mut pv.engine))) {
        Ok(o) => convert(o),
        Err(_) => {
            let _ = catch_unwind(AssertUnwindSafe(|| pv.engine.reset()));
            PvResult::unchanged()
        }
    }
}

/// Tạo engine với cấu hình mặc định. Giải phóng bằng `pv_engine_free`.
#[no_mangle]
pub extern "C" fn pv_engine_new() -> *mut PvEngine {
    catch_unwind(|| {
        Box::into_raw(Box::new(PvEngine {
            engine: Engine::new(Config::default()),
        }))
    })
    .unwrap_or(ptr::null_mut())
}

/// # Safety
/// `e` là NULL hoặc con trỏ từ `pv_engine_new`, chưa được giải phóng.
#[no_mangle]
pub unsafe extern "C" fn pv_engine_free(e: *mut PvEngine) {
    if !e.is_null() {
        let _ = catch_unwind(AssertUnwindSafe(|| drop(Box::from_raw(e))));
    }
}

/// Đặt cấu hình từ JSON (xem `Config::from_json`). Trả 0 nếu thành công, -1 nếu lỗi
/// (cấu hình cũ được giữ nguyên).
///
/// # Safety
/// `e` hợp lệ; `json` là NULL hoặc chuỗi C kết thúc NUL.
#[no_mangle]
pub unsafe extern "C" fn pv_set_config(e: *mut PvEngine, json: *const c_char) -> i32 {
    if e.is_null() || json.is_null() {
        return -1;
    }
    let pv = &mut *e;
    let r = catch_unwind(AssertUnwindSafe(|| {
        let s = CStr::from_ptr(json).to_str().map_err(|_| ())?;
        let c = Config::from_json(s).map_err(|_| ())?;
        pv.engine.set_config(c);
        Ok::<(), ()>(())
    }));
    match r {
        Ok(Ok(())) => 0,
        _ => -1,
    }
}

/// Gửi một phím. `codepoint`: ký tự Unicode đã áp Shift; `flags`: `PV_FLAG_*`.
/// Ký tự không phải phím của kiểu gõ → chốt từ (COMMIT, pass_through) hoặc UNCHANGED.
///
/// # Safety
/// `e` hợp lệ.
#[no_mangle]
pub unsafe extern "C" fn pv_process(e: *mut PvEngine, codepoint: u32, flags: u32) -> PvResult {
    let Some(ch) = char::from_u32(codepoint) else {
        return PvResult::unchanged();
    };
    with_engine(e, |en| {
        en.process(KeyInput::with_flags(
            ch,
            flags & PV_FLAG_SHIFT != 0,
            flags & PV_FLAG_CAPS != 0,
        ))
    })
}

/// # Safety
/// `e` hợp lệ.
#[no_mangle]
pub unsafe extern "C" fn pv_backspace(e: *mut PvEngine) -> PvResult {
    with_engine(e, |en| en.backspace())
}

/// Chốt từ. `boundary`: `PV_BOUNDARY_*`; `codepoint` chỉ dùng với `PV_BOUNDARY_CHAR`.
///
/// # Safety
/// `e` hợp lệ.
#[no_mangle]
pub unsafe extern "C" fn pv_commit(e: *mut PvEngine, boundary: i32, codepoint: u32) -> PvResult {
    let b = match boundary {
        PV_BOUNDARY_SPACE => Boundary::Space,
        PV_BOUNDARY_ENTER => Boundary::Enter,
        PV_BOUNDARY_TAB => Boundary::Tab,
        PV_BOUNDARY_CHAR => Boundary::Char(char::from_u32(codepoint).unwrap_or('?')),
        PV_BOUNDARY_MOUSE => Boundary::Mouse,
        PV_BOUNDARY_FOCUS => Boundary::Focus,
        _ => Boundary::Other,
    };
    with_engine(e, |en| en.commit(b))
}

/// ESC: trả lại phím thô.
///
/// # Safety
/// `e` hợp lệ.
#[no_mangle]
pub unsafe extern "C" fn pv_restore_raw(e: *mut PvEngine) -> PvResult {
    with_engine(e, |en| en.restore_raw())
}

/// # Safety
/// `e` hợp lệ.
#[no_mangle]
pub unsafe extern "C" fn pv_reset(e: *mut PvEngine) {
    if !e.is_null() {
        let pv = &mut *e;
        let _ = catch_unwind(AssertUnwindSafe(|| pv.engine.reset()));
    }
}

/// Đang có từ dở?
///
/// # Safety
/// `e` hợp lệ.
#[no_mangle]
pub unsafe extern "C" fn pv_is_composing(e: *const PvEngine) -> bool {
    !e.is_null() && (*e).engine.is_composing()
}

/// Chữ đang hiển thị (giải phóng bằng `pv_string_free`).
///
/// # Safety
/// `e` hợp lệ.
#[no_mangle]
pub unsafe extern "C" fn pv_composing(e: *const PvEngine) -> *mut c_char {
    if e.is_null() {
        return ptr::null_mut();
    }
    to_c((*e).engine.composing().to_string())
}

/// Giải phóng chuỗi do thư viện trả về. NULL được bỏ qua.
///
/// # Safety
/// `s` là NULL hoặc chuỗi do thư viện này trả về, chưa được giải phóng.
#[no_mangle]
pub unsafe extern "C" fn pv_string_free(s: *mut c_char) {
    if !s.is_null() {
        drop(CString::from_raw(s));
    }
}

/// Phiên bản thư viện (chuỗi tĩnh, KHÔNG giải phóng).
#[no_mangle]
pub extern "C" fn pv_version() -> *const c_char {
    concat!(env!("CARGO_PKG_VERSION"), "\0").as_ptr() as *const c_char
}

#[cfg(test)]
mod tests {
    use super::*;

    unsafe fn take(r: PvResult) -> (i32, String, bool) {
        let s = if r.text.is_null() {
            String::new()
        } else {
            CStr::from_ptr(r.text).to_str().unwrap().to_string()
        };
        pv_string_free(r.text);
        (r.kind, s, r.pass_through)
    }

    #[test]
    fn roundtrip_through_c_abi() {
        unsafe {
            let e = pv_engine_new();
            assert!(!e.is_null());
            let mut last = (0, String::new(), false);
            for c in "vieejt".chars() {
                last = take(pv_process(e, c as u32, 0));
            }
            assert_eq!(last, (PV_COMPOSING, "việt".into(), false));
            assert!(pv_is_composing(e));
            let c = take(pv_commit(e, PV_BOUNDARY_SPACE, 0));
            assert_eq!(c, (PV_COMMIT, "việt".into(), true));
            assert_eq!(take(pv_backspace(e)).0, PV_UNCHANGED);

            let json = CString::new(r#"{"method":"vni"}"#).unwrap();
            assert_eq!(pv_set_config(e, json.as_ptr()), 0);
            let bad = CString::new("{oops").unwrap();
            assert_eq!(pv_set_config(e, bad.as_ptr()), -1);
            for c in "a1".chars() {
                last = take(pv_process(e, c as u32, 0));
            }
            assert_eq!(last.1, "á");
            assert_eq!(take(pv_restore_raw(e)), (PV_COMMIT, "a1".into(), false));
            // codepoint không hợp lệ
            assert_eq!(take(pv_process(e, 0xD800, 0)).0, PV_UNCHANGED);
            // Caps Lock
            let _ = take(pv_process(e, 'a' as u32, PV_FLAG_CAPS));
            let s = pv_composing(e);
            assert_eq!(CStr::from_ptr(s).to_str().unwrap(), "A");
            pv_string_free(s);
            pv_reset(e);
            assert!(!pv_is_composing(e));
            pv_engine_free(e);
            // NULL an toàn
            assert_eq!(
                take(pv_process(ptr::null_mut(), 'a' as u32, 0)).0,
                PV_UNCHANGED
            );
            assert_eq!(pv_set_config(ptr::null_mut(), json.as_ptr()), -1);
            pv_engine_free(ptr::null_mut());
            pv_string_free(ptr::null_mut());
        }
    }
}

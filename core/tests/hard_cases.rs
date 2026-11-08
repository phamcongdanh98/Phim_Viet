//! Bộ ca khó viết tay (ENGINE_RULES). Mỗi dòng: (phím, kết quả sau khi chốt bằng dấu cách).
//! `\u{8}` = Backspace, `\u{1b}` = ESC.

mod common;
use common::*;
use phimviet_core::{Config, InputMethod};

fn check(c: &Config, cases: &[(&str, &str)], name: &str) -> usize {
    let mut bad = Vec::new();
    for (keys, want) in cases {
        let got = typed(c, keys);
        if got != *want {
            bad.push(format!("{name}: {keys:?} → {got:?}, cần {want:?}"));
        }
    }
    assert!(bad.is_empty(), "\n{}", bad.join("\n"));
    cases.len()
}

fn check_shown(c: &Config, cases: &[(&str, &str)], name: &str) -> usize {
    let mut bad = Vec::new();
    for (keys, want) in cases {
        let got = shown(c, keys);
        if got != *want {
            bad.push(format!("{name}: {keys:?} → {got:?}, cần {want:?}"));
        }
    }
    assert!(bad.is_empty(), "\n{}", bad.join("\n"));
    cases.len()
}

const TELEX: &[(&str, &str)] = &[
    // --- gõ dấu tự do (§4)
    ("vieejt", "việt"),
    ("vieetj", "việt"),
    ("vietje", "việt"),
    ("vietej", "việt"),
    ("viejet", "việt"),
    ("tieengs", "tiếng"),
    ("tieesng", "tiếng"),
    ("tiengse", "tiếng"),
    ("tienges", "tiếng"),
    ("tieensg", "tiếng"),
    ("toans", "toán"),
    ("toasn", "toán"),
    ("tosan", "toán"),
    ("thuowng", "thương"),
    ("thuwowng", "thương"),
    ("thuongw", "thương"),
    ("truowngf", "trường"),
    ("truongwf", "trường"),
    ("truongfw", "trường"),
    ("nguoiwf", "người"),
    ("nguowif", "người"),
    ("nguwowif", "người"),
    ("nguoifw", "người"),
    ("dduowngf", "đường"),
    ("duongwfd", "đường"),
    ("dduwowngf", "đường"),
    ("dduwowcj", "được"),
    ("duwowcjd", "được"),
    ("nuwowcs", "nước"),
    ("ruwowuj", "rượu"),
    ("ruouwj", "rượu"),
    ("muwa", "mưa"),
    ("muaw", "mưa"),
    ("cuwar", "cửa"),
    ("cuarw", "cửa"),
    ("huwu", "hưu"),
    ("cuwus", "cứu"),
    ("cuusw", "cứu"),
    // --- đặt thanh (§5)
    ("hoaf", "hoà"),
    ("hoafng", "hoàng"),
    ("hoangf", "hoàng"),
    ("khoer", "khoẻ"),
    ("thuyr", "thuỷ"),
    ("thury", "thuỷ"),
    ("haif", "hài"),
    ("mias", "mía"),
    ("muaf", "mùa"),
    ("khoais", "khoái"),
    ("ngoays", "ngoáy"),
    ("chuoois", "chuối"),
    ("khuya", "khuya"),
    ("khuyas", "khuýa"),
    ("khuyur", "khuỷu"),
    ("ngoeoj", "ngoẹo"),
    ("khuyeechs", "khuyếch"),
    ("khueechs", "khuếch"),
    ("hoawcj", "hoặc"),
    ("xoawn", "xoăn"),
    ("loawts", "loắt"),
    ("huynhf", "huỳnh"),
    ("huychs", "huých"),
    ("tuyps", "tuýp"),
    ("huees", "huế"),
    ("tuaans", "tuấn"),
    ("luaatj", "luật"),
    ("khuaays", "khuấy"),
    ("quaays", "quấy"),
    ("ddaauf", "đầu"),
    ("chaof", "chào"),
    ("tooi", "tôi"),
    ("baanj", "bận"),
    ("khoong", "không"),
    ("yeeu", "yêu"),
    ("yeeus", "yếu"),
    ("ys", "ý"),
    ("uyeen", "uyên"),
    ("oaf", "oà"),
    ("oes", "oé"),
    ("ddeef", "đề"),
    // --- gi / qu
    ("quas", "quá"),
    ("quys", "quý"),
    ("quyeenr", "quyển"),
    ("quoocs", "quốc"),
    ("quaan", "quân"),
    ("queen", "quên"),
    ("quets", "quét"),
    ("quow", "quơ"),
    ("giaf", "già"),
    ("gieengs", "giếng"),
    ("gieets", "giết"),
    ("gif", "gì"),
    ("gifn", "gìn"),
    ("ginf", "gìn"),
    ("giuwax", "giữa"),
    ("giowf", "giờ"),
    ("gioongs", "giống"),
    ("giuwowngf", "giường"),
    ("giawtj", "giặt"),
    ("gias", "giá"),
    ("gisa", "giá"),
    // --- uơ / ươ
    ("huow", "huơ"),
    ("thuowr", "thuở"),
    ("thuowrng", "thưởng"),
    ("khuow", "khuơ"),
    // --- uyê, oong, ooc
    ("khuyeets", "khuyết"),
    ("nguyeenx", "nguyễn"),
    ("nguyeexn", "nguyễn"),
    ("nguyenex", "nguyễn"),
    ("chuyeenj", "chuyện"),
    ("tuyeets", "tuyết"),
    ("xooong", "xoong"),
    ("booong", "boong"),
    ("xoong", "xông"),
    ("mooocs", "moóc"),
    ("gooongf", "goòng"),
    ("cooocs", "coóc"),
    // --- k / gh / ngh / c / g
    ("keeu", "kêu"),
    ("kieemr", "kiểm"),
    ("ghee", "ghê"),
    ("ghees", "ghế"),
    ("nghieeng", "nghiêng"),
    ("nghix", "nghĩ"),
    ("ngheej", "nghệ"),
    ("ngoaif", "ngoài"),
    ("kys", "ký"),
    ("kis", "kí"),
    // --- gõ đúp để huỷ (§4.6)
    ("aaa", "aa"),
    ("aaaa", "aaa"),
    ("ass", "as"),
    ("asss", "ass"),
    ("ddd", "dd"),
    ("ww", "w"),
    ("www", "ww"),
    ("aww", "aw"),
    ("ooo", "oo"),
    ("eee", "ee"),
    ("uww", "uw"),
    ("off", "of"),
    ("iff", "if"),
    ("orr", "or"),
    ("dd", "đ"),
    ("ddi", "đi"),
    ("did", "đi"),
    ("dod", "đo"),
    ("dawngd", "đăng"),
    ("dand", "đan"),
    // --- xoá thanh z
    ("asz", "a"),
    ("vieejnz", "viên"),
    ("tieengsz", "tiêng"),
    ("hoafz", "hoa"),
    // --- đổi thanh
    ("asf", "à"),
    ("tieengsf", "tiềng"),
    ("hoasr", "hoả"),
    // --- hoa / thường (§10)
    ("VIEETJ", "VIỆT"),
    ("Vieejt", "Việt"),
    ("Dd", "Đ"),
    ("DD", "Đ"),
    ("dD", "đ"),
    ("TieengS", "Tiếng"),
    ("NGUYEENX", "NGUYỄN"),
    ("Nguyeenx", "Nguyễn"),
    ("DDUWOWNGF", "ĐƯỜNG"),
    ("Dduwowngf", "Đường"),
    ("Ddaf", "Đà"),
    ("W", "Ư"),
    ("Tw", "Tư"),
    ("TW", "TƯ"),
    ("QUOOCS", "QUỐC"),
    ("GIAF", "GIÀ"),
    ("HOAF", "HOÀ"),
    ("THUOWR", "THUỞ"),
    ("VieEjt", "Việt"),
    ("ViEejt", "ViỆt"),
    // --- w đứng riêng
    ("w", "ư"),
    ("tw", "tư"),
    ("nhw", "như"),
    ("trwowngf", "trường"),
    ("thwj", "thự"),
    ("wf", "ừ"),
    // --- nhiều từ, ranh giới (§11)
    ("Tooi yeeu Vieejt Nam", "Tôi yêu Việt Nam"),
    ("ddaf Nawngx", "đà Nẵng"),
    ("vieejt,", "việt,"),
    ("vieejt.", "việt."),
    ("vieejt2", "việt2"),
    ("vieejt2s", "việt2s"),
    ("tieengs Vieejt!", "tiếng Việt!"),
    ("(vieejt)", "(việt)"),
    ("a-b", "a-b"),
    ("123", "123"),
    (
        "chaof banj, minhf laf Phism Vieejt",
        "chào bạn, mình là Phím Việt",
    ),
    ("Hoom nay trowif ddepj quas", "Hôm nay trời đẹp quá"),
    (
        "Cong hoaf xax hooij chur nghiax Vieejt Nam",
        "Cong hoà xã hội chủ nghĩa Việt Nam",
    ),
    (
        "Coongj hoaf xax hooij chur nghiax Vieejt Nam",
        "Cộng hoà xã hội chủ nghĩa Việt Nam",
    ),
    // --- ESC (§9)
    ("vieejt\u{1b}", "vieejt"),
    ("tieengs\u{1b}", "tieengs"),
    ("dd\u{1b}", "dd"),
    ("\u{1b}abc", "abc"),
    // --- backspace (§8)
    ("tieengs\u{8}g", "tiếng"),
    ("vieejt\u{8}t", "việt"),
    ("vieejt\u{8}\u{8}", "vi"),
    ("vieejt\u{8}\u{8}eejt", "việt"),
    ("hoaf\u{8}af", "hoà"),
    ("dd\u{8}", ""),
    ("ddi\u{8}", "đ"),
    ("ddc", "đc"),
    ("ddt", "đt"),
    ("100ddd", "100dd"),
    ("vieejtss", "vieejtss"),
    ("ddi\u{8}a", "đa"),
    ("nguowif\u{8}\u{8}", "ngư"),
    ("nguowif\u{8}\u{8}owif", "người"),
    ("xooong\u{8}g", "xoong"),
    ("ab\u{8}\u{8}\u{8}c", "c"),
    ("wit\u{8}th", "with"),
    ("issu\u{8}ue", "issue"),
    ("a \u{8}\u{8}b", "b"),
    // --- tự khôi phục tiếng Anh (§7)
    ("text", "text"),
    ("expect", "expect"),
    ("perfect", "perfect"),
    ("with", "with"),
    ("case", "case"),
    ("user", "user"),
    ("push", "push"),
    ("wow", "wow"),
    ("class", "class"),
    ("issue", "issue"),
    ("string", "string"),
    ("return", "return"),
    ("function", "function"),
    ("export", "export"),
    ("select", "select"),
    ("update", "update"),
    ("delete", "delete"),
    ("server", "server"),
    ("docker", "docker"),
    ("release", "release"),
    ("request", "request"),
    ("commit", "commit"),
    ("merge", "merge"),
    ("review", "review"),
    ("data", "data"),
    ("new", "new"),
    ("view", "view"),
    ("law", "law"),
    ("process", "process"),
    ("access", "access"),
    ("success", "success"),
    ("address", "address"),
    ("express", "express"),
    ("assert", "assert"),
    ("dead", "dead"),
    ("keep", "keep"),
    ("deep", "deep"),
    ("dude", "dude"),
    ("banana", "banana"),
    ("area", "area"),
    ("az", "az"),
    // --- giữ tiếng Việt khi vừa hợp lệ (giới hạn đã biết)
    ("mix", "mĩ"),
    ("box", "bõ"),
    ("test", "tét"),
];

const TELEX_SHOWN: &[(&str, &str)] = &[
    ("wit", "wit"),
    ("w", "ư"),
    ("data", "dât"),
    ("thuowr", "thuở"),
    ("huow", "huơ"),
    ("nguow", "nguơ"),
    ("nguowi", "ngươi"),
    ("aaa", "aa"),
    ("ass", "as"),
    ("iss", "is"),
    ("issu", "issu"),
    ("class", "class"),
    ("clas", "clas"),
    ("tiengs", "tiéng"),
    ("tiengse", "tiếng"),
    ("text", "tẽt"),
    ("tex", "tẽ"),
    ("str", "str"),
    ("ngh", "ngh"),
    ("qu", "qu"),
    ("gi", "gi"),
    ("gis", "gí"),
    ("gisa", "giá"),
    ("dd", "đ"),
    ("ddd", "dd"),
    ("toana", "toana"),
    ("dduwowngf", "đường"),
    ("vieejt ", "việt "),
];

const TELEX_OLD: &[(&str, &str)] = &[
    ("hoaf", "hòa"),
    ("khoer", "khỏe"),
    ("thuyr", "thủy"),
    ("hoafng", "hoàng"),
    ("oaf", "òa"),
    ("quys", "quý"),
    ("khoais", "khoái"),
    ("thuys", "thúy"),
    ("hoaj", "họa"),
    ("toans", "toán"),
];

const SIMPLE: &[(&str, &str)] = &[
    ("w", "w"),
    ("tw", "tw"),
    ("uw", "ư"),
    ("tuw", "tư"),
    ("thuowng", "thương"),
    ("vieejt", "việt"),
    ("muaw", "mưa"),
    ("nhuw", "như"),
];

const VNI: &[(&str, &str)] = &[
    ("vie65t", "việt"),
    ("vie6t5", "việt"),
    ("viet65", "việt"),
    ("viet56", "việt"),
    ("tie61ng", "tiếng"),
    ("tieng61", "tiếng"),
    ("tieng16", "tiếng"),
    ("d9uo7ng2", "đường"),
    ("duong792", "đường"),
    ("duong297", "đường"),
    ("d9u7o7ng2", "đường"),
    ("nguoi72", "người"),
    ("nguo7i2", "người"),
    ("thuo7ng", "thương"),
    ("hoa2", "hoà"),
    ("khoe3", "khoẻ"),
    ("thuy3", "thuỷ"),
    ("a11", "a1"),
    ("a111", "a11"),
    ("a66", "a6"),
    ("d99", "d9"),
    ("u77", "u7"),
    ("a88", "a8"),
    ("Vie65t", "Việt"),
    ("VIE65T", "VIỆT"),
    ("D9", "Đ"),
    ("d9", "đ"),
    ("thuo73", "thuở"),
    ("huo7", "huơ"),
    ("quo61c", "quốc"),
    ("quoc61", "quốc"),
    ("a8n", "ăn"),
    ("a8n1", "ắn"),
    ("mu7a", "mưa"),
    ("mua7", "mưa"),
    ("1a", "1a"),
    ("b1", "b1"),
    ("to6i", "tôi"),
    ("kho6ng", "không"),
    ("u7", "ư"),
    ("o7", "ơ"),
    ("a8", "a8"),
    ("a8m", "ăm"),
    ("a6", "a6"),
    ("a6m", "âm"),
    ("e6", "ê"),
    ("o6", "ô"),
    ("a1", "á"),
    ("a2", "à"),
    ("a3", "ả"),
    ("a4", "ã"),
    ("a5", "ạ"),
    ("a10", "a"),
    ("vie65n0", "viên"),
    ("gia2", "già"),
    ("gi2", "gì"),
    ("gi2n", "gìn"),
    ("qua1", "quá"),
    ("quy1", "quý"),
    ("quye6n3", "quyển"),
    ("khuye6t1", "khuyết"),
    ("nguye6n4", "nguyễn"),
    ("xoong", "xoong"),
    ("hoa8c5", "hoặc"),
    ("hoac85", "hoặc"),
    ("ru7o7u5", "rượu"),
    ("ruou75", "rượu"),
    ("cu7u1", "cứu"),
    ("cuu71", "cứu"),
    ("khuyu3", "khuỷu"),
    ("ngoai2", "ngoài"),
    ("To6i ye6u Vie65t Nam", "Tôi yêu Việt Nam"),
    ("vie65t\u{1b}", "vie65t"),
    ("vie65t\u{8}t", "việt"),
    ("tie61ng\u{8}g", "tiếng"),
    ("text", "text"),
    ("with", "with"),
    ("abc123", "abc123"),
    ("Windows10", "Windows10"),
    ("d9i", "đi"),
    ("di9", "đi"),
];

const BRACKETS: &[(&str, &str)] = &[("t]", "tư"), ("t[", "tơ"), ("t[i", "tơi"), ("]", "ư")];

#[test]
fn hard_cases() {
    let mut n = 0;
    n += check(&telex(), TELEX, "telex");
    n += check_shown(&telex(), TELEX_SHOWN, "telex-shown");
    n += check(&old_style(telex()), TELEX_OLD, "telex-old");
    n += check(&cfg(InputMethod::SimpleTelex), SIMPLE, "simple");
    n += check(&vni(), VNI, "vni");
    let mut b = telex();
    b.brackets = true;
    n += check(&b, BRACKETS, "brackets");
    // tắt `[ ]` → là dấu câu
    n += check(&telex(), &[("t]", "t]"), ("t[", "t[")], "no-brackets");
    println!("số ca khó: {n}");
    assert!(n >= 300, "chỉ có {n} ca");
}

#[test]
fn spell_check_off() {
    let mut c = telex();
    c.spell_check = false;
    assert_eq!(shown(&c, "wit"), "ưit");
    assert_eq!(typed(&c, "wit"), "wit"); // tự khôi phục vẫn bật
    c.auto_restore = false;
    assert_eq!(typed(&c, "wit"), "ưit");
    assert_eq!(typed(&c, "vieejt"), "việt");
}

#[test]
fn auto_restore_off() {
    let mut c = telex();
    c.auto_restore = false;
    assert_eq!(typed(&c, "text"), "tẽt");
    assert_eq!(typed(&c, "with"), "with"); // kiểm tra âm tiết vẫn hiện phím thô
    assert_eq!(typed(&c, "data"), "dât");
}

#[test]
fn macros() {
    let mut c = telex();
    c.macros = vec![
        ("vn".into(), "Việt Nam".into()),
        ("ko".into(), "không".into()),
        ("đc".into(), "được".into()),
        ("hn".into(), "Hà Nội".into()),
    ];
    assert_eq!(typed(&c, "vn"), "Việt Nam");
    assert_eq!(typed(&c, "Vn"), "Việt Nam");
    assert_eq!(typed(&c, "VN"), "VIỆT NAM");
    assert_eq!(typed(&c, "ko "), "không ");
    assert_eq!(typed(&c, "Ko,"), "Không,");
    assert_eq!(typed(&c, "KO"), "KHÔNG");
    assert_eq!(typed(&c, "ddc"), "được");
    assert_eq!(typed(&c, "toi o hn."), "toi o Hà Nội.");
    assert_eq!(typed(&c, "vnx"), "vnx");
    // ESC không bung gõ tắt
    assert_eq!(typed(&c, "vn\u{1b}"), "vn");
    c.macros_enabled = false;
    assert_eq!(typed(&c, "vn"), "vn");
}

#[test]
fn mouse_and_focus_boundaries_skip_macros() {
    use phimviet_core::{Boundary, Engine, KeyInput, Output};
    let mut c = telex();
    c.macros = vec![("vn".into(), "Việt Nam".into())];
    let mut e = Engine::new(c);
    e.process(KeyInput::new('v'));
    e.process(KeyInput::new('n'));
    assert_eq!(
        e.commit(Boundary::Mouse),
        Output::Commit {
            text: "vn".into(),
            pass_through: false
        }
    );
    assert_eq!(e.commit(Boundary::Space), Output::Unchanged);
}

#[test]
fn caps_lock_flag() {
    use phimviet_core::{Engine, KeyInput};
    let mut e = Engine::new(telex());
    for ch in "vieejt".chars() {
        e.process(KeyInput::with_flags(ch, false, true));
    }
    assert_eq!(e.composing(), "VIỆT");
}

#[test]
fn set_config_rerenders() {
    use phimviet_core::{Engine, KeyInput, ToneStyle};
    let mut e = Engine::new(telex());
    for ch in "hoaf".chars() {
        e.process(KeyInput::new(ch));
    }
    assert_eq!(e.composing(), "hoà");
    let mut c = telex();
    c.tone_style = ToneStyle::Old;
    e.set_config(c);
    assert_eq!(e.composing(), "hòa");
}

#[test]
fn long_word_freezes() {
    use phimviet_core::{Engine, KeyInput};
    let mut e = Engine::new(telex());
    for _ in 0..500 {
        e.process(KeyInput::new('a'));
    }
    assert!(e.composing().chars().count() <= 500);
    assert!(e.composing().chars().all(|c| c == 'a' || c == 'â'));
}

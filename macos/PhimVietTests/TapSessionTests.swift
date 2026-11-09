import Foundation
import Testing
@testable import PhimVietKit

/// Ứng dụng giả cho chế độ app chạy riêng: nhận phím thật hoặc lệnh ⌫/gõ chữ do bộ gõ gửi.
final class TapDoc {
    let session: TapSession
    var text = ""
    /// Số lần bộ gõ phải gửi phím giả (để kiểm tra chỉ gửi khi cần).
    var injections = 0

    init(config: String? = nil) {
        session = TapSession(engine: RustEngine()!)
        if let config { session.engine.setConfig(json: config) }
    }

    private func appKey(_ k: String) {
        if k == "\u{8}" {
            if !text.isEmpty { text.removeLast() }
        } else if k != "\u{1b}" {
            text += k
        }
    }

    func type(_ keys: String) {
        for ch in keys {
            let k = String(ch)
            let action: TapAction
            switch k {
            case "\u{8}": action = session.backspace()
            case "\u{1b}": action = session.escape()
            default:
                let up = ch.isUppercase
                action = session.key(k, shift: up, caps: false)
            }
            switch action {
            case .pass: appKey(k)
            case .consume: break
            case .replace(let d, let ins, let original):
                injections += 1
                for _ in 0..<d where !text.isEmpty { text.removeLast() }
                text += ins
                if original { appKey(k) }
            }
        }
    }

    /// Mô phỏng click chuột / phím điều hướng.
    func click() { session.reset() }
}

@Suite("TapSession")
struct TapSessionTests {
    @Test func diffCountsCharacters() {
        #expect(TapSession.diff("vie", "viê") == (1, "ê"))
        #expect(TapSession.diff("tiêng", "tiếng") == (3, "ếng"))
        #expect(TapSession.diff("", "ư") == (0, "ư"))
        #expect(TapSession.diff("vn", "Việt Nam") == (2, "Việt Nam"))
    }

    @Test func sentence() {
        let d = TapDoc()
        d.type("Coongj hoaf xax hooij chur nghiax Vieejt Nam.\r")
        #expect(d.text == "Cộng hoà xã hội chủ nghĩa Việt Nam.\r")
    }

    @Test func plainLettersAreNeverInjected() {
        let d = TapDoc()
        d.type("hello big cat ")
        #expect(d.text == "hello big cat ")
        #expect(d.injections == 0)
    }

    @Test func englishAutoRestore() {
        let d = TapDoc()
        d.type("data with express delete ")
        #expect(d.text == "data with express delete ")
    }

    @Test func userConfigSpellCheckOff() {
        let d = TapDoc(config: #"{"method":"telex","tone_style":"old","spell_check":false,"auto_restore":true}"#)
        d.type("hoom nay laf thuws hai delete select border, hoaf.")
        #expect(d.text == "hôm nay là thứ hai delete select border, hòa.")
    }

    @Test func backspaceInsideWord() {
        let d = TapDoc()
        d.type("vieejt\u{8}\u{8}eetj ")
        #expect(d.text == "việt ")
        let d2 = TapDoc()
        d2.type("nguoiwf\u{8}")
        #expect(d2.text == "ngườ")
    }

    @Test func rewindAfterSpace() {
        let d = TapDoc()
        d.type("may \u{8}as ")
        #expect(d.text == "mấy ")
        d.type("may \u{8}fa ")
        #expect(d.text == "mấy mầy ")
    }

    @Test func rewindNeedsExactlyOneBackspace() {
        let d = TapDoc()
        d.type("may  \u{8}\u{8}as ")  // hai dấu cách, hai ⌫ → không nối lại (an toàn)
        #expect(d.text == "mayá ")
        let d2 = TapDoc()
        d2.type("may \u{8}")
        d2.click()  // con trỏ có thể đã đổi chỗ
        d2.type("as ")
        #expect(d2.text == "mayá ")
    }

    @Test func rewindLeavesEnglishWordsAlone() {
        let d = TapDoc()
        d.type("with \u{8}s ")
        #expect(d.text == "withs ")
    }

    @Test func escapeRestoresRaw() {
        let d = TapDoc()
        d.type("vieejt\u{1b} ")
        #expect(d.text == "vieejt ")
    }

    @Test func macroExpandsBeforeSpace() {
        let d = TapDoc(config: #"{"method":"telex","macros_enabled":true,"macros":{"vn":"Việt Nam"}}"#)
        d.type("vn vn.")
        #expect(d.text == "Việt Nam Việt Nam.")
    }

    @Test func vni() {
        let d = TapDoc(config: #"{"method":"vni"}"#)
        d.type("Vie65t Nam d9e5p qua1 ")
        #expect(d.text == "Việt Nam đẹp quá ")
    }

    @Test func clickMidWordStartsFresh() {
        let d = TapDoc()
        d.type("vie")
        d.click()
        d.type("es ")
        // Sau click không biết con trỏ ở đâu → không sửa chữ cũ, "es" là từ mới.
        #expect(d.text == "vieé ")
    }

    @Test func injectionPolicy() {
        if case .clearSuggestion = InjectionMethod.forApp("com.google.Chrome") {} else { Issue.record("chrome") }
        if case .backspace(let b, _, _) = InjectionMethod.forApp("com.microsoft.Word") { #expect(b > 0) } else {
            Issue.record("word")
        }
        #expect(InjectionMethod.forApp("com.apple.TextEdit") == .backspace(between: 0, wait: 1000, text: 0))
    }
}

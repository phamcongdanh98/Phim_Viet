import Foundation
import Testing
@testable import PhimVietKit

@Suite("CompositionSession")
struct SessionTests {
    func trusted(_ bundle: String = "com.example.editor") -> ClientTrust {
        let t = ClientTrust()
        t.record(bundle, proved: true)
        return t
    }

    @Test func standardAppProvesThenTypesDirect() {
        let c = FakeClient()
        let trust = ClientTrust()
        let t = Typist(client: c, trust: trust)
        t.type("tieengs ")
        #expect(c.text == "tiếng ")
        #expect(trust.state(c.bundleIdentifier) == .trusted)
        c.writes.removeAll()
        t.type("vieejt ")
        #expect(c.text == "tiếng việt ")
        #expect(!c.writes.contains("mark"))  // từ thứ hai gõ trực tiếp
        #expect(c.marked.location == NSNotFound)
    }

    @Test func markedPathProducesSameText() {
        let c = FakeClient()
        let t = Typist(client: c, direct: false)
        t.type("Tooi yeeu Vieejt Nam, dduwowngf phoos! ")
        #expect(c.text == "Tôi yêu Việt Nam, đường phố! ")
        #expect(c.marked.location == NSNotFound)
    }

    @Test func directSentence() {
        let c = FakeClient()
        let t = Typist(client: c, trust: trusted())
        t.type("Coongj hoaf xax hooij chur nghiax Vieejt Nam.\r")
        #expect(c.text == "Cộng hoà xã hội chủ nghĩa Việt Nam.\r")
    }

    @Test func unreadableAppStaysMarked() {
        let c = FakeClient()
        c.readable = false
        let trust = ClientTrust()
        let t = Typist(client: c, trust: trust)
        t.type("tieengs vieejt ")
        #expect(c.text == "tiếng việt ")
        #expect(trust.state(c.bundleIdentifier) == .distrusted)
        c.writes.removeAll()
        t.type("nhes ")
        #expect(c.writes.contains("mark"))
        #expect(c.text == "tiếng việt nhé ")
    }

    @Test func lyingCaretAppNeverGetsDirect() {
        // Chromium/Cursor: selectedRange trả (1,0) dù tài liệu dài 5
        let c = FakeClient()
        c.lyingSelection = NSRange(location: 1, length: 0)
        let trust = ClientTrust()
        let t = Typist(client: c, trust: trust)
        t.type("tieengs vieejt ")
        #expect(c.text == "tiếng việt ")
        #expect(trust.state(c.bundleIdentifier) == .distrusted)
    }

    @Test func lyingCaretAfterTrustAbandonsWithoutOverwrite() {
        let c = FakeClient()
        c.doc.setString("hello ")
        c.sel = NSRange(location: 6, length: 0)
        let trust = trusted()
        let t = Typist(client: c, trust: trust)
        t.type("vie")
        #expect(c.text == "hello vie")
        c.lyingSelection = NSRange(location: 1, length: 0)
        t.type("e")  // cần thay "e" → "ê": không kiểm chứng được
        #expect(c.text.hasPrefix("hello vie"))
        #expect(trust.state(c.bundleIdentifier) == .distrusted)
        #expect(!c.text.contains("ê") || c.marked.location != NSNotFound)
    }

    @Test func autocorrectingAppIsNeverOverwritten() {
        let c = FakeClient()
        // app viết hoa chữ đầu tài liệu sau mỗi lần sửa
        c.autocorrect = { s in s.isEmpty ? s : s.prefix(1).uppercased() + s.dropFirst() }
        let trust = trusted()
        let t = Typist(client: c, trust: trust)
        t.type("vieej")
        // "vie" đã thành "Vie" do app → không được ghi đè; phím "e" bắt đầu từ mới
        #expect(c.text.hasPrefix("Vie"))
        #expect(trust.state(c.bundleIdentifier) == .distrusted)
        t.finish()
        #expect(c.marked.location == NSNotFound)
    }

    @Test func inlineSuggestionIsReplaced() {
        let c = FakeClient()
        c.suggestion = { doc in doc.hasSuffix(" ") || doc.isEmpty ? nil : "namnet.vn" }
        let t = Typist(client: c, trust: trusted())
        t.type("vieejt ")
        #expect(c.text == "việt ")
    }

    @Test func clickMidWordEndsWordWithoutTouchingIt() {
        let c = FakeClient()
        var clicks = 0
        let t = Typist(client: c, trust: trusted(), clicks: { clicks })
        t.type("vie")
        clicks += 1
        c.moveCaret(to: 0)
        t.type("e")
        #expect(c.text == "evie")
        t.type("s ")
        #expect(c.text == "é vie")
    }

    @Test func backspaceInDirectModeIsPassedToApp() {
        let c = FakeClient()
        let t = Typist(client: c, trust: trusted())
        t.type("vieejt")
        let readsBefore = c.reads
        t.type("\u{8}")
        #expect(c.text == "việ")
        #expect(c.reads == readsBefore)
        t.type("t ")
        #expect(c.text == "việt ")
        t.type("\u{8}\u{8}")  // không còn từ dở → app tự xoá
        #expect(c.text == "việ")
    }

    @Test func backspaceToEmptyInMarkedMode() {
        let c = FakeClient()
        let t = Typist(client: c, direct: false)
        t.type("ab\u{8}\u{8}")
        #expect(c.text == "")
        #expect(c.marked.location == NSNotFound)
        #expect(!t.session.isComposing)
        t.type("\u{8}")  // không có từ → app xử lý
        #expect(c.text == "")
    }

    @Test func escapeRestoresRawKeys() {
        let c = FakeClient()
        let t = Typist(client: c, trust: trusted())
        t.type("vieejt\u{1b}")
        #expect(c.text == "vieejt")
        let c2 = FakeClient()
        let t2 = Typist(client: c2, direct: false)
        t2.type("vieejt\u{1b} ")
        #expect(c2.text == "vieejt ")
    }

    @Test func autoRestoreInDirectMode() {
        let c = FakeClient()
        let t = Typist(client: c, trust: trusted())
        t.type("text with user ")
        #expect(c.text == "text with user ")
    }

    @Test func focusLossInDirectModeLeavesTextAsShown() {
        let c = FakeClient()
        let t = Typist(client: c, trust: trusted())
        t.type("tex")
        t.session.deactivate(client: c)
        #expect(c.text == "tẽ")
        #expect(!t.session.isComposing)
    }

    @Test func focusLossInMarkedModeCommits() {
        let c = FakeClient()
        let t = Typist(client: c, direct: false)
        t.type("vieejt")
        t.session.deactivate(client: c)
        #expect(c.text == "việt")
        #expect(c.marked.location == NSNotFound)
    }

    @Test func arrowKeyCommitsWithRestore() {
        let c = FakeClient()
        let t = Typist(client: c, trust: trusted())
        t.type("text")
        t.session.commit(.other, client: c)
        #expect(c.text == "text")
    }

    @Test func activateWithUnknownCaretForcesMarked() {
        let c = FakeClient()
        c.lyingSelection = notFoundRange
        let t = Typist(client: c, trust: trusted())
        t.type("vieejt")
        #expect(t.session.presenter?.kind == .marked)
        t.finish()
        #expect(c.text == "việt")
    }

    @Test func multiScalarKeyCommitsAndPasses() {
        let c = FakeClient()
        let t = Typist(client: c, trust: trusted())
        t.type("vieejt")
        #expect(t.session.handleKey("ab", shift: false, caps: false, client: c) == false)
        #expect(!t.session.isComposing)
    }

    @Test func randomTypingNeverLeavesMarkedTextOrCrashes() {
        var rng = SystemRandomNumberGenerator()
        let alphabet = Array("aeouiydwsfrxjzntgchqAEDW .,\u{8}\u{1b}")
        for direct in [true, false] {
            for _ in 0..<300 {
                let c = FakeClient()
                let t = Typist(client: c, trust: direct ? trusted() : ClientTrust(), direct: direct)
                var keys = ""
                for _ in 0..<30 { keys.append(alphabet.randomElement(using: &rng)!) }
                t.type(keys)
                t.finish()
                #expect(c.marked.location == NSNotFound, "\(keys)")
                #expect(!c.text.unicodeScalars.contains { (0x300...0x36F).contains($0.value) })
            }
        }
    }
}

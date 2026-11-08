import Foundation
import Testing
@testable import PhimVietKit

@Suite("DirectEdit")
struct DirectEditTests {
    func client(_ text: String, caret: Int? = nil) -> FakeClient {
        let c = FakeClient()
        c.doc.setString(text)
        c.sel = NSRange(location: caret ?? (text as NSString).length, length: 0)
        return c
    }

    @Test func commonPrefixByCharacter() {
        #expect(DirectEdit.commonPrefixCount("tieng", "tiếng") == 2)
        #expect(DirectEdit.commonPrefixCount("việ", "việt") == 3)
        #expect(DirectEdit.commonPrefixCount("", "a") == 0)
        // "ệ" không bị tách thành "e" + dấu
        #expect(DirectEdit.commonPrefixCount("vie\u{0323}\u{0302}", "việ") == 2)
    }

    @Test func appendDoesNotReadDocument() {
        let c = client("abc ")
        #expect(DirectEdit.edit(from: "vi", to: "vie", client: c) == .appended)
        #expect(c.reads == 0)
        #expect(c.text == "abc e")
    }

    @Test func replaceVerifiesThenEdits() {
        let c = client("xin vie")
        #expect(DirectEdit.edit(from: "vie", to: "viê", client: c) == .replaced)
        #expect(c.text == "xin viê")
        #expect(c.sel == NSRange(location: 7, length: 0))
        #expect(DirectEdit.edit(from: "viê", to: "việt", client: c) == .replaced)
        #expect(c.text == "xin việt")
    }

    @Test func mismatchNeverOverwrites() {
        let c = client("xin Vie")  // app đã tự viết hoa
        #expect(DirectEdit.edit(from: "vie", to: "viê", client: c) == .abandoned(.mismatch))
        #expect(c.text == "xin Vie")
        #expect(c.writes.isEmpty)
    }

    @Test func lyingCaretIsRejected() {
        let c = client("hello vie")
        c.lyingSelection = NSRange(location: 1, length: 0)  // Chromium/Cursor
        #expect(DirectEdit.edit(from: "vie", to: "viê", client: c) == .abandoned(.caretBeforeWord))
        #expect(c.text == "hello vie")
    }

    @Test func lyingCaretInsideDocumentIsRejectedByContent() {
        let c = client("ab vie xyz")
        c.lyingSelection = NSRange(location: 6, length: 0)
        c.sel = NSRange(location: 10, length: 0)
        // con trỏ báo sai cố định → không dịch sau khi chèn → bị phát hiện (rà soát #1)
        #expect(DirectEdit.edit(from: "xyz", to: "xyzz", client: c) == .unverified(.caretMoved))
        // vị trí 6 không có "xyz" ngay trước → không ghi
        let c2 = client("ab vie xyz")
        c2.lyingSelection = NSRange(location: 6, length: 0)
        #expect(DirectEdit.edit(from: "xyz", to: "xỹz", client: c2) == .abandoned(.mismatch))
        #expect(c2.text == "ab vie xyz")
    }

    @Test func unreadableClientAbandons() {
        let c = client("vie")
        c.readable = false
        #expect(DirectEdit.edit(from: "vie", to: "viê", client: c) == .abandoned(.unreadable))
        #expect(c.text == "vie")
    }

    @Test func notFoundSelectionAbandons() {
        let c = client("vie")
        c.lyingSelection = notFoundRange
        #expect(DirectEdit.edit(from: "vie", to: "viê", client: c) == .abandoned(.noSelection))
    }

    @Test func documentShorterThanCaretAbandons() {
        let c = client("vie")
        c.lyingLength = 1
        #expect(DirectEdit.edit(from: "vie", to: "viê", client: c) == .abandoned(.documentTooShort))
    }

    @Test func nfdDocumentIsNotConfusedWithNFC() {
        // Tài liệu chứa "viê" dạng NFD (4 đơn vị UTF-16); `==` của Swift coi là bằng nhau, ta thì không.
        let c = client("vie\u{0302}")
        #expect(DirectEdit.edit(from: "viê", to: "viêt", client: c) == .appended)
        #expect(DirectEdit.edit(from: "viêt", to: "viết", client: c) == .abandoned(.mismatch))
        let c2 = client("vie\u{0302}")
        #expect(DirectEdit.edit(from: "viê", to: "việ", client: c2) != .replaced)
        #expect(c2.text == "vie\u{0302}")
    }

    @Test func selectedSuggestionAfterCaretIsReplacedToo() {
        // thanh URL: "vie|tnamnet.vn" — phần sau con trỏ đang bôi đen
        let c = client("vietnamnet.vn", caret: 3)
        c.sel = NSRange(location: 3, length: 10)
        #expect(DirectEdit.edit(from: "vie", to: "viê", client: c) == .replaced)
        #expect(c.text == "viê")
    }

    @Test func shrinkDeletesTail() {
        let c = client("ok tẽt")
        #expect(DirectEdit.edit(from: "tẽt", to: "text", client: c) == .replaced)
        #expect(c.text == "ok text")
        let c2 = client("ok abc")
        #expect(DirectEdit.edit(from: "abc", to: "a", client: c2) == .replaced)
        #expect(c2.text == "ok a")
    }

    @Test func replacementIgnoredByAppIsDetected() {
        let c = client("xin chao")
        c.ignoresReplacementRange = true
        #expect(DirectEdit.edit(from: "chao", to: "chào", client: c) == .unverified(.caretMoved))
    }

    @Test func appendChecksCaretAdvance() {
        let c = client("ab")
        #expect(DirectEdit.edit(from: "", to: "xy", client: c) == .appended)
        #expect(c.sel.location == 4)
    }
}

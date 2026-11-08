import Foundation
@testable import PhimVietKit

/// Client giả mô phỏng một ô nhập liệu, có thể cấu hình hành vi "xấu".
final class FakeClient: TextClient {
    var bundleIdentifier = "com.example.editor"
    let doc = NSMutableString()
    var sel = NSRange(location: 0, length: 0)
    var marked = notFoundRange

    // --- hành vi xấu
    /// Không hỗ trợ đọc tài liệu (`attributedSubstring` trả nil).
    var readable = true
    /// Báo vị trí con trỏ sai (Chromium/Cursor trả (1,0) dù tài liệu dài hơn).
    var lyingSelection: NSRange?
    /// `length()` trả giá trị sai.
    var lyingLength: Int?
    /// Sau mỗi lần chèn, app tự sửa chữ (autocorrect): nhận cả tài liệu, trả tài liệu mới.
    var autocorrect: ((String) -> String)?
    /// Gợi ý tự hoàn thành: sau mỗi lần chèn, app thêm phần gợi ý được bôi đen sau con trỏ.
    var suggestion: ((String) -> String?)?
    /// App bỏ qua `replacementRange`, luôn chèn tại con trỏ.
    var ignoresReplacementRange = false
    /// App báo trễ (Chromium/Electron): `selectedRange`/đọc tài liệu trả trạng thái lúc bắt đầu phím,
    /// chỉ cập nhật khi `tick()` (giữa hai phím).
    var lagging = false
    private var snapDoc = ""
    private var snapSel = NSRange(location: 0, length: 0)

    func tick() {
        snapDoc = doc as String
        snapSel = sel
    }

    var reads = 0
    var writes: [String] = []

    var text: String { doc as String }

    func selectedRange() -> NSRange { lyingSelection ?? (lagging ? snapSel : sel) }
    func markedRange() -> NSRange { marked }
    func documentLength() -> Int? { lyingLength ?? doc.length }

    func text(in range: NSRange) -> String? {
        reads += 1
        let d: NSString = lagging ? snapDoc as NSString : doc
        guard readable, range.location >= 0, range.location + range.length <= d.length else { return nil }
        return d.substring(with: range)
    }

    private func replace(_ r: NSRange, with s: String) {
        doc.replaceCharacters(in: r, with: s)
    }

    /// Bỏ phần gợi ý đang bôi đen (app làm vậy khi người dùng gõ tiếp).
    private func clearSuggestion() {
        if sel.length > 0, suggestion != nil {
            replace(sel, with: "")
            sel.length = 0
        }
    }

    private func afterEdit() {
        if let ac = autocorrect {
            let before = text
            let after = ac(before)
            if after != before {
                doc.setString(after)
                sel = NSRange(location: min(sel.location + (after as NSString).length - (before as NSString).length, doc.length), length: 0)
            }
        }
        if let sug = suggestion, let extra = sug(text), !extra.isEmpty {
            replace(NSRange(location: sel.location, length: 0), with: extra)
            sel = NSRange(location: sel.location, length: (extra as NSString).length)
        }
    }

    func insertText(_ s: String, replacementRange: NSRange) {
        writes.append("insert")
        let target: NSRange
        if marked.location != NSNotFound {
            target = marked
            marked = notFoundRange
        } else if replacementRange.location == NSNotFound || ignoresReplacementRange {
            target = sel
        } else {
            target = replacementRange
        }
        replace(target, with: s)
        sel = NSRange(location: target.location + (s as NSString).length, length: 0)
        afterEdit()
    }

    func setMarkedText(_ s: String, selectionRange: NSRange, replacementRange: NSRange) {
        writes.append("mark")
        let target = marked.location != NSNotFound ? marked : sel
        replace(target, with: s)
        let len = (s as NSString).length
        marked = len > 0 ? NSRange(location: target.location, length: len) : notFoundRange
        sel = NSRange(location: target.location + selectionRange.location, length: 0)
    }

    /// Ứng dụng tự xử lý phím mà IME trả lại (`handle` → false).
    func appHandles(_ key: String) {
        if key == "\u{8}" {
            if sel.length > 0 {
                replace(sel, with: "")
                sel.length = 0
            } else if sel.location > 0 {
                let r = doc.rangeOfComposedCharacterSequence(at: sel.location - 1)
                replace(r, with: "")
                sel = NSRange(location: r.location, length: 0)
            }
            return
        }
        if key == "\u{1b}" { return }
        clearSuggestion()
        replace(sel, with: key)
        sel = NSRange(location: sel.location + (key as NSString).length, length: 0)
        afterEdit()
    }

    /// App tự chốt marked text (ví dụ khi click) mà không báo cho IME.
    func dropMarked() {
        marked = notFoundRange
    }

    /// Đặt con trỏ (mô phỏng click chuột).
    func moveCaret(to loc: Int) {
        sel = NSRange(location: loc, length: 0)
    }
}

/// Mô phỏng `PhimVietInputController.handle`: gửi từng phím qua session; phím không được xử lý thì app tự làm.
struct Typist {
    let session: CompositionSession
    let client: FakeClient

    init(client: FakeClient, trust: ClientTrust = ClientTrust(), direct: Bool = true,
         clicks: @escaping () -> Int = { 0 }) {
        let engine = RustEngine()!
        session = CompositionSession(engine: engine, trust: trust)
        session.directTypingEnabled = direct
        session.clickCounter = clicks
        self.client = client
        session.activate(client: client)
    }

    func type(_ keys: String) {
        for ch in keys {
            client.tick()
            let k = String(ch)
            let handled: Bool
            switch k {
            case "\u{8}": handled = session.handleBackspace(client: client)
            case "\u{1b}": handled = session.handleEscape(client: client)
            default: handled = session.handleKey(k, shift: false, caps: false, client: client)
            }
            if !handled { client.appHandles(k) }
        }
    }

    func finish() {
        session.commit(.other, client: client)
    }
}

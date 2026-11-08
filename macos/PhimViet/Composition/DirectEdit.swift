import Foundation

/// Ghi trực tiếp vào tài liệu ("gõ không gạch chân") một cách an toàn.
///
/// Không lưu vị trí tuyệt đối trong tài liệu (Monaco/Electron dựng lại textarea giữa các phím);
/// chỉ dựa vào `shown` — chuỗi chính ta đã ghi cho từ hiện tại — và vị trí con trỏ đọc ngay lúc sửa.
public enum DirectEdit {
    public enum Outcome: Equatable {
        /// Không có gì thay đổi.
        case unchanged
        /// Chỉ thêm đuôi tại con trỏ (không cần đọc tài liệu).
        case appended
        /// Đã thay phần đuôi khác biệt sau khi kiểm chứng.
        case replaced
        /// Không kiểm chứng được → KHÔNG ghi gì.
        case abandoned(Reason)
        /// Đã ghi nhưng kiểm tra sau khi ghi không khớp (con trỏ không dịch đúng / chữ đọc lại sai)
        /// → app không đáng tin, phải kết thúc từ và rút quyền.
        case unverified(Reason)
    }

    public enum Reason: Error, Equatable {
        case noSelection
        case caretBeforeWord
        case documentTooShort
        case unreadable
        case mismatch
        /// Con trỏ sau khi ghi không ở vị trí dự kiến.
        case caretMoved
        /// Đọc lại sau khi thay không ra đúng chữ mới.
        case postCheckFailed
    }

    /// Tiền tố chung theo `Character` (không tách dấu khỏi nguyên âm).
    public static func commonPrefixCount(_ a: String, _ b: String) -> Int {
        var n = 0
        var ia = a.makeIterator()
        var ib = b.makeIterator()
        while let x = ia.next(), let y = ib.next(), String(x).utf16Equals(String(y)) {
            n += 1
        }
        return n
    }

    /// Vùng từ hiện tại trong tài liệu sau khi kiểm chứng: chữ ngay trước con trỏ phải đúng là `shown`.
    public struct Region: Equatable {
        public let start: Int
        public let selectionLength: Int
    }

    public static func verifiedRegion(shown: String, client: TextClient) -> Result<Region, Reason> {
        let sel = client.selectedRange()
        let n = shown.utf16.count
        guard sel.location != NSNotFound, sel.length != NSNotFound, sel.length >= 0,
              sel.location >= 0, sel.location <= Int(Int32.max)
        else { return .failure(.noSelection) }
        guard sel.location >= n else { return .failure(.caretBeforeWord) }
        // Chrome/Electron luôn trả `length() = 0` (không hỗ trợ) → coi 0 là "không biết";
        // an toàn vẫn được bảo đảm bởi bước đọc lại chữ ngay bên dưới.
        if let len = client.documentLength(), len > 0, len < sel.location + sel.length {
            return .failure(.documentTooShort)
        }
        let start = sel.location - n
        guard let actual = client.text(in: NSRange(location: start, length: n)) else {
            return .failure(.unreadable)
        }
        guard actual.utf16Equals(shown) else { return .failure(.mismatch) }
        return .success(Region(start: start, selectionLength: sel.length))
    }

    /// Trạng thái tài liệu dự kiến sau một lần ghi mà app chưa kịp báo lại (Chromium/Electron cập nhật
    /// vị trí con trỏ bất đồng bộ). Được kiểm tra ở lần sửa kế tiếp, trước khi ghi.
    public struct Pending: Equatable {
        /// Vị trí con trỏ dự kiến.
        public let caret: Int
        /// Đầu từ trong tài liệu.
        public let start: Int
        /// Chữ dự kiến tại `[start, caret)`.
        public let text: String

        public init(caret: Int, start: Int, text: String) {
            self.caret = caret
            self.start = start
            self.text = text
        }

        /// Tài liệu đúng như dự kiến? `slack`: số ký tự app có thể đã chèn thêm sau con trỏ (phím cách…).
        public func holds(in client: TextClient, slack: Int = 0) -> Bool {
            let loc = client.selectedRange().location
            guard loc != NSNotFound, loc >= caret, loc <= caret + slack, start >= 0,
                  let t = client.text(in: NSRange(location: start, length: text.utf16.count))
            else { return false }
            return t.utf16Equals(text)
        }
    }

    /// Đưa tài liệu từ `shown` sang `new`.
    ///
    /// - Chỉ thêm đuôi: chèn tại con trỏ (luôn an toàn), không đọc tài liệu.
    /// - Cần thay: đọc và so khớp chữ trước con trỏ; nếu còn `pending` từ lần ghi trước thì nó phải đúng.
    /// - Sau mỗi lần ghi: con trỏ đúng vị trí dự kiến → xong; con trỏ chưa đổi (app báo trễ) → trả `Pending`
    ///   để kiểm ở lần sau; con trỏ ở chỗ khác → `.unverified`.
    public static func edit(from shown: String, to new: String, client: TextClient,
                            pending: Pending? = nil) -> (Outcome, Pending?) {
        if shown.utf16Equals(new) { return (.unchanged, pending) }
        let common = commonPrefixCount(shown, new)
        let oldTailIsEmpty = shown.count == common
        let newTail = String(new.dropFirst(common))
        let n = new.utf16.count
        if oldTailIsEmpty {
            let before = client.selectedRange()
            client.insertText(newTail, replacementRange: notFoundRange)
            if let p = pending {
                // Chưa kiểm được lần ghi trước: mang kỳ vọng tiếp (chèn tại con trỏ vẫn an toàn).
                let caret = p.caret + newTail.utf16.count
                return (.appended, Pending(caret: caret, start: caret - n, text: new))
            }
            guard before.location != NSNotFound, before.location >= 0 else { return (.appended, nil) }
            let expected = before.location + newTail.utf16.count
            return settle(after: client.selectedRange().location, before: before.location,
                          expected: expected, word: new, staleWord: nil, client: client, ok: .appended)
        }
        if let p = pending, !p.holds(in: client) {
            return (.abandoned(.postCheckFailed), nil)
        }
        switch verifiedRegion(shown: shown, client: client) {
        case .failure(let r):
            return (.abandoned(r), nil)
        case .success(let region):
            let prefixLen = String(shown.prefix(common)).utf16.count
            // Phủ cả vùng chọn sau con trỏ (gợi ý tự hoàn thành của thanh URL, Spotlight, Excel).
            let range = NSRange(
                location: region.start + prefixLen,
                length: shown.utf16.count - prefixLen + region.selectionLength
            )
            let before = region.start + shown.utf16.count
            client.insertText(newTail, replacementRange: range)
            return settle(after: client.selectedRange().location, before: before,
                          expected: region.start + n, word: new, staleWord: shown, client: client,
                          ok: .replaced)
        }
    }

    private static func settle(after: Int, before: Int, expected: Int, word: String, staleWord: String?,
                               client: TextClient, ok: Outcome) -> (Outcome, Pending?) {
        let n = word.utf16.count
        let pending = Pending(caret: expected, start: expected - n, text: word)
        if after == expected {
            // Thêm đuôi: con trỏ dịch đúng là đủ, không đọc tài liệu.
            guard staleWord != nil else { return (ok, nil) }
            guard let back = client.text(in: NSRange(location: expected - n, length: n)) else {
                return (.unverified(.postCheckFailed), nil)
            }
            if back.utf16Equals(word) { return (ok, nil) }
            if let stale = staleWord, back.utf16Equals(stale) { return (ok, pending) }  // nội dung báo trễ
            return (.unverified(.postCheckFailed), nil)
        }
        if after == before && after != expected {
            return (ok, pending)  // con trỏ báo trễ → kiểm ở lần sau
        }
        return (.unverified(.caretMoved), nil)
    }
}

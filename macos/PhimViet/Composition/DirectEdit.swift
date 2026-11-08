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
        if let len = client.documentLength(), len < sel.location + sel.length {
            return .failure(.documentTooShort)
        }
        let start = sel.location - n
        guard let actual = client.text(in: NSRange(location: start, length: n)) else {
            return .failure(.unreadable)
        }
        guard actual.utf16Equals(shown) else { return .failure(.mismatch) }
        return .success(Region(start: start, selectionLength: sel.length))
    }

    /// Đưa tài liệu từ `shown` sang `new`.
    ///
    /// Sau mỗi lần ghi đều kiểm tra con trỏ dịch đúng độ dài vừa ghi (chặn app báo con trỏ sai —
    /// trùng hợp nội dung với từ ngắn không đủ để tin); sau khi thay còn đọc lại cả từ.
    public static func edit(from shown: String, to new: String, client: TextClient) -> Outcome {
        if shown.utf16Equals(new) { return .unchanged }
        let common = commonPrefixCount(shown, new)
        let oldTailIsEmpty = shown.count == common
        let newTail = String(new.dropFirst(common))
        if oldTailIsEmpty {
            let before = client.selectedRange()
            client.insertText(newTail, replacementRange: notFoundRange)
            if before.location != NSNotFound, before.location >= 0 {
                let after = client.selectedRange()
                if after.location != before.location + newTail.utf16.count {
                    return .unverified(.caretMoved)
                }
            }
            return .appended
        }
        switch verifiedRegion(shown: shown, client: client) {
        case .failure(let r):
            return .abandoned(r)
        case .success(let region):
            let prefixLen = String(shown.prefix(common)).utf16.count
            // Phủ cả vùng chọn sau con trỏ (gợi ý tự hoàn thành của thanh URL, Spotlight, Excel).
            let range = NSRange(
                location: region.start + prefixLen,
                length: shown.utf16.count - prefixLen + region.selectionLength
            )
            client.insertText(newTail, replacementRange: range)
            let n = new.utf16.count
            guard client.selectedRange().location == region.start + n else {
                return .unverified(.caretMoved)
            }
            guard let back = client.text(in: NSRange(location: region.start, length: n)),
                  back.utf16Equals(new)
            else { return .unverified(.postCheckFailed) }
            return .replaced
        }
    }
}

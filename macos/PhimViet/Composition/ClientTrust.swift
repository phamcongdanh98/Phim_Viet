import Foundation

/// Theo dõi ứng dụng nào đã **chứng minh** đọc lại tài liệu chính xác (được phép gõ trực tiếp).
/// Không có danh sách app cứng: chỉ dựa vào kết quả đọc lại thực tế. Nhớ theo bundle id trong phiên.
public final class ClientTrust {
    public enum State: Equatable {
        case unknown
        case trusted
        case distrusted
    }

    private var states: [String: State] = [:]
    /// Vị trí (cuối từ) của lần chứng minh thành công đầu tiên, chờ lần thứ hai.
    private var firstProof: [String: Int] = [:]

    public init() {}

    public func state(_ bundle: String) -> State {
        states[bundle] ?? .unknown
    }

    public func allowsDirect(_ bundle: String) -> Bool {
        state(bundle) == .trusted
    }

    /// Ghi nhận một lần chứng minh tại vị trí `position` (cuối chữ vừa chèn).
    /// Cần **hai** lần thành công ở hai vị trí khác nhau mới được tin: app báo con trỏ sai cố định
    /// chỉ có thể trùng hợp ở đúng một vị trí. Thất bại → mất quyền tới hết phiên.
    public func record(_ bundle: String, proved: Bool, position: Int) {
        guard state(bundle) == .unknown else {
            if !proved { states[bundle] = .distrusted }
            return
        }
        guard proved else {
            states[bundle] = .distrusted
            firstProof[bundle] = nil
            return
        }
        if let p = firstProof[bundle], p != position {
            states[bundle] = .trusted
            firstProof[bundle] = nil
        } else {
            firstProof[bundle] = position
        }
    }

    /// Tin ngay (chỉ dùng cho test).
    public func trustForTesting(_ bundle: String) {
        states[bundle] = .trusted
    }

    public func revoke(_ bundle: String) {
        states[bundle] = .distrusted
    }

    /// Quên mọi đánh giá (ví dụ khi người dùng bật lại "gõ không gạch chân").
    public func reset() {
        states.removeAll()
        firstProof.removeAll()
    }

    /// Đọc lại: chữ ngay trước con trỏ đúng là `text`.
    public static func readBack(_ text: String, client: TextClient) -> Bool {
        if case .success = DirectEdit.verifiedRegion(shown: text, client: client) { return true }
        return false
    }

    /// Chứng minh sau khi chốt marked text: con trỏ phải nằm đúng ở cuối chữ vừa chèn
    /// (`markedStart` + độ dài — vị trí lấy từ `markedRange()` TRƯỚC khi chèn) và đọc lại đúng chữ đó.
    /// So nội dung thôi không đủ: app báo con trỏ sai cố định có thể trùng hợp với từ ngắn.
    public static func proveAfterCommit(_ text: String, markedStart: Int?, client: TextClient) -> Bool {
        guard let start = markedStart, start != NSNotFound, start >= 0 else { return false }
        guard client.selectedRange().location == start + text.utf16.count else { return false }
        return readBack(text, client: client)
    }

    /// Client có báo vị trí con trỏ không (kiểm tra lúc activate).
    public static func supportsReading(_ client: TextClient) -> Bool {
        let sel = client.selectedRange()
        return sel.location != NSNotFound && sel.location >= 0
    }
}

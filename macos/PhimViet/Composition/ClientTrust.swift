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

    /// Chứng minh sau khi chốt marked text: chữ ngay trước con trỏ phải đúng là chữ vừa chèn.
    /// Trả vị trí con trỏ nếu đạt. KHÔNG dựa vào `markedRange()` — Chrome báo nó theo hệ toạ độ riêng.
    /// Một lần đạt chưa đủ: `record` cần hai vị trí khác nhau (chặn app báo con trỏ sai cố định).
    public static func proveAfterCommit(_ text: String, client: TextClient) -> Int? {
        guard readBack(text, client: client) else { return nil }
        return client.selectedRange().location
    }

    /// Client có báo vị trí con trỏ không (kiểm tra lúc activate).
    public static func supportsReading(_ client: TextClient) -> Bool {
        let sel = client.selectedRange()
        return sel.location != NSNotFound && sel.location >= 0
    }
}

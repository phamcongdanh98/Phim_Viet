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

    public init() {}

    public func state(_ bundle: String) -> State {
        states[bundle] ?? .unknown
    }

    public func allowsDirect(_ bundle: String) -> Bool {
        state(bundle) == .trusted
    }

    /// Ghi nhận một lần chứng minh. Thất bại → mất quyền tới hết phiên.
    public func record(_ bundle: String, proved: Bool) {
        if proved {
            if state(bundle) == .unknown { states[bundle] = .trusted }
        } else {
            states[bundle] = .distrusted
        }
    }

    public func revoke(_ bundle: String) {
        states[bundle] = .distrusted
    }

    /// Quên mọi đánh giá (ví dụ khi người dùng bật lại "gõ không gạch chân").
    public func reset() {
        states.removeAll()
    }

    /// Đọc lại: chữ ngay trước con trỏ đúng là `text`.
    public static func readBack(_ text: String, client: TextClient) -> Bool {
        if case .success = DirectEdit.verifiedRegion(shown: text, client: client) { return true }
        return false
    }

    /// Client có báo vị trí con trỏ không (kiểm tra lúc activate).
    public static func supportsReading(_ client: TextClient) -> Bool {
        let sel = client.selectedRange()
        return sel.location != NSNotFound && sel.location >= 0
    }
}

import Foundation

/// Trừu tượng hoá client của InputMethodKit (`IMKTextInput`) để test được bằng client giả.
/// Mọi vị trí/độ dài tính bằng đơn vị UTF-16 (như `NSString`).
public protocol TextClient: AnyObject {
    /// Bundle id của ứng dụng đang nhận chữ (rỗng nếu không rõ).
    var bundleIdentifier: String { get }
    func selectedRange() -> NSRange
    func markedRange() -> NSRange
    /// Độ dài tài liệu; `nil` nếu client không cho biết.
    func documentLength() -> Int?
    /// Chữ trong `range`; `nil` nếu client không hỗ trợ đọc tài liệu.
    func text(in range: NSRange) -> String?
    func insertText(_ text: String, replacementRange: NSRange)
    func setMarkedText(_ text: String, selectionRange: NSRange, replacementRange: NSRange)
}

/// `NSRange(location: NSNotFound, length: 0)` — "tại con trỏ / vùng marked hiện tại".
public let notFoundRange = NSRange(location: NSNotFound, length: 0)

extension String {
    /// So khớp chính xác từng đơn vị UTF-16 (KHÔNG dùng `==` vì `==` coi NFC và NFD là bằng nhau,
    /// trong khi độ dài UTF-16 khác nhau sẽ làm lệch vùng thay thế).
    @inline(__always)
    func utf16Equals(_ other: String) -> Bool {
        utf16.elementsEqual(other.utf16)
    }
}

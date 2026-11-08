import Foundation

/// Phím tắt chuyển Việt/Anh chỉ gồm phím bổ trợ (mặc định ⌃⇧): nhấn rồi nhả, không kèm phím khác.
/// Nhận cờ thô của `NSEvent.modifierFlags.rawValue` qua `flagsChanged`.
public struct ModifierToggle {
    public static let shift: UInt = 1 << 17
    public static let control: UInt = 1 << 18
    public static let option: UInt = 1 << 19
    public static let command: UInt = 1 << 20
    public static let relevantMask: UInt = shift | control | option | command

    /// Tổ hợp cần nhấn; 0 = tắt.
    public var required: UInt
    private var armed = false

    public init(required: UInt) {
        self.required = required
    }

    /// Trả `true` khi tổ hợp vừa được nhả ra trọn vẹn (kích hoạt chuyển chế độ).
    public mutating func flagsChanged(_ raw: UInt) -> Bool {
        guard required != 0 else { return false }
        let m = raw & Self.relevantMask
        if m == required {
            armed = true
        } else if m == 0 {
            defer { armed = false }
            return armed
        } else if armed && (m & ~required) == 0 {
            // đang nhả dần từng phím của tổ hợp
        } else {
            armed = false
        }
        return false
    }

    /// Có phím thường được nhấn trong lúc giữ tổ hợp → không phải lệnh chuyển.
    public mutating func keyDown() {
        armed = false
    }
}

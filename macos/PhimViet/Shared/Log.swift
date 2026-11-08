import Foundation
import os

/// Nhật ký hệ thống. Bản phát hành KHÔNG ghi nội dung người dùng gõ — chỉ sự kiện, độ dài, hành động.
/// Xem: `log stream --predicate 'subsystem == "com.phimviet.inputmethod.PhimViet"'`
public enum Log {
    public static let subsystem = "com.phimviet.inputmethod.PhimViet"
    public static let input = Logger(subsystem: subsystem, category: "input")
    public static let app = Logger(subsystem: subsystem, category: "app")

    /// Chỉ trả nội dung khi build với `-D PHIMVIET_DEBUG_TEXT`; ngược lại chỉ có độ dài.
    public static func redact(_ s: String) -> String {
        #if PHIMVIET_DEBUG_TEXT
        return s
        #else
        return "<\(s.utf16.count)>"
        #endif
    }
}

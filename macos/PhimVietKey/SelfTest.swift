import Cocoa

/// Tự kiểm tra trên máy thật: `PhimVietKey --selftest <pid> <phím>`.
///
/// Gõ giả lập như bàn phím thật (tầng HID, không có dấu PVKY) để chính Phím Việt Key đang chạy xử lý,
/// rồi ứng dụng test (pid) tự ghi lại kết quả. An toàn:
/// - chỉ nhận chữ thường a–z, số, dấu cách, dấu chấm và `<` (= ⌫), tối đa 120 phím;
/// - trước MỖI phím đều kiểm tra ứng dụng đang ở trên cùng đúng là `pid`, sai → dừng ngay.
enum SelfTest {
    private static let keyCodes: [Character: CGKeyCode] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11,
        "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21,
        "6": 22, "5": 23, "9": 25, "7": 26, "8": 28, "0": 29, "o": 31, "u": 32, "i": 34, "p": 35,
        "l": 37, "j": 38, "k": 40, "n": 45, "m": 46, ".": 47, " ": 49, "<": 51,
    ]

    /// Trả mã thoát: 0 xong, 2 sai tham số, 3 chưa có quyền, 4 ứng dụng test không ở trên cùng.
    static func run(_ args: [String]) -> Int32 {
        guard args.count == 2, let pid = pid_t(args[0]), pid > 0 else { return 2 }
        let keys = Array(args[1])
        guard !keys.isEmpty, keys.count <= 120, keys.allSatisfy({ keyCodes[$0] != nil }) else { return 2 }
        guard AXIsProcessTrusted() else { return 3 }
        let src = CGEventSource(stateID: .hidSystemState)
        for ch in keys {
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return 4 }
            let code = keyCodes[ch]!
            for down in [true, false] {
                guard let e = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: down) else { continue }
                e.post(tap: .cghidEventTap)
                usleep(down ? 30_000 : 90_000)
            }
        }
        return 0
    }
}

import Cocoa

/// Tự kiểm tra trên máy thật: `PhimVietKey --selftest <pid> <phím> [ms/phím]`.
///
/// Gõ giả lập như bàn phím thật (tầng HID, không có dấu PVKY) để chính Phím Việt Key đang chạy xử lý,
/// rồi ứng dụng test (pid) tự ghi lại kết quả. An toàn:
/// - chỉ nhận chữ a–z / A–Z (chữ hoa gửi kèm Shift), số, dấu cách, dấu chấm và `<` (= ⌫), tối đa 200 phím;
/// - tốc độ 20–500 ms mỗi phím (mặc định 120);
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
        guard args.count == 2 || args.count == 3, let pid = pid_t(args[0]), pid > 0 else { return 2 }
        let keys = Array(args[1])
        let ms = args.count == 3 ? Int(args[2]) ?? 0 : 120
        guard (20...500).contains(ms), !keys.isEmpty, keys.count <= 200,
              keys.allSatisfy({ keyCodes[Character($0.lowercased())] != nil })
        else { return 2 }
        guard AXIsProcessTrusted() else { return 3 }
        let src = CGEventSource(stateID: .hidSystemState)
        let half = useconds_t(ms * 500)
        // Chữ hoa: nhấn Shift (flagsChanged) như bàn phím thật và LUÔN nhả khi kết thúc — nếu chỉ gắn cờ Shift
        // lên phím chữ, hệ thống tưởng Shift còn giữ và mọi phím sau (kể cả của người dùng) thành chữ hoa.
        var shiftDown = false
        func setShift(_ on: Bool) {
            guard on != shiftDown, let e = CGEvent(keyboardEventSource: src, virtualKey: 56, keyDown: on) else { return }
            e.type = .flagsChanged
            e.flags = on ? .maskShift : []
            e.post(tap: .cghidEventTap)
            shiftDown = on
            usleep(half)
        }
        defer { setShift(false) }
        for ch in keys {
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return 4 }
            let code = keyCodes[Character(ch.lowercased())]!
            setShift(ch.isUppercase)
            for down in [true, false] {
                guard let e = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: down) else { continue }
                e.flags = shiftDown ? .maskShift : []
                e.post(tap: .cghidEventTap)
                usleep(half)
            }
        }
        return 0
    }
}

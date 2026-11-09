import Cocoa

/// Dấu gắn trên mọi phím do Phím Việt Key gửi — để không tự xử lý lại chính nó.
let kInjectedMarker: Int64 = 0x5056_4B59  // "PVKY"

/// Chặn phím toàn hệ thống (cần quyền Trợ năng / Accessibility).
/// `handler` trả `nil` để nuốt phím, hoặc trả lại sự kiện để nó đi tiếp.
final class KeyTap {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    var handler: (CGEventType, CGEvent) -> CGEvent? = { _, e in e }

    var isRunning: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    func start() -> Bool {
        if tap != nil { return true }
        let types: [CGEventType] = [.keyDown, .flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let me = Unmanaged<KeyTap>.fromOpaque(refcon).takeUnretainedValue()
            return me.handle(type, event)
        }
        guard let t = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque())
        else { return false }
        tap = t
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        return true
    }

    func stop() {
        if let t = tap { CGEvent.tapEnable(tap: t, enable: false) }
        if let s = source { CFRunLoopRemoveSource(CFRunLoopGetMain(), s, .commonModes) }
        tap = nil
        source = nil
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // macOS tắt tap nếu xử lý quá lâu — bật lại ngay.
            if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == kInjectedMarker {
            return Unmanaged.passUnretained(event)
        }
        guard let out = handler(type, event) else { return nil }
        return Unmanaged.passUnretained(out)
    }
}

/// Gửi phím ⌫ và chữ Unicode vào ứng dụng đang dùng.
final class Injector {
    private let source = CGEventSource(stateID: .privateState)
    private static let backspaceKey: CGKeyCode = 51
    /// Ký tự "vô hình" dùng để huỷ phần gợi ý đang bôi đen trên thanh địa chỉ trình duyệt.
    private static let breaker = "\u{202F}"
    /// Không kèm phím bổ trợ nào, NHƯNG giữ `maskNonCoalesced`: thiếu cờ này macOS gộp các phím ⌫ giống hệt nhau
    /// gửi liền nhau thành một → chỉ xoá được 1 ký tự (lỗi `laf` → `laà` trên Chrome).
    static let plainFlags: CGEventFlags = .maskNonCoalesced

    private func post(_ e: CGEvent) {
        e.setIntegerValueField(.eventSourceUserData, value: kInjectedMarker)
        e.post(tap: .cgSessionEventTap)
    }

    private func tap(_ key: CGKeyCode) {
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down) else { continue }
            e.flags = Self.plainFlags
            post(e)
        }
    }

    /// Gõ chuỗi theo từng đoạn ≤ 20 đơn vị UTF-16, không cắt giữa một ký tự.
    private func type(_ s: String, delay: UInt32) {
        var chunks: [[UniChar]] = []
        var cur: [UniChar] = []
        for ch in s {
            let u = Array(String(ch).utf16)
            if cur.count + u.count > 20, !cur.isEmpty {
                chunks.append(cur)
                cur = []
            }
            cur += u
        }
        if !cur.isEmpty { chunks.append(cur) }
        for (i, c) in chunks.enumerated() {
            if i > 0, delay > 0 { usleep(delay) }
            for down in [true, false] {
                guard let e = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: down) else { continue }
                e.flags = Self.plainFlags
                c.withUnsafeBufferPointer { e.keyboardSetUnicodeString(stringLength: c.count, unicodeString: $0.baseAddress) }
                post(e)
            }
        }
    }

    /// Xoá `delete` ký tự trước con trỏ, gõ `insert`, rồi gửi lại phím gốc (nếu có).
    func replace(delete: Int, insert: String, method: InjectionMethod, original: CGEvent?) {
        var n = delete
        let between: UInt32
        let wait: UInt32
        let textDelay: UInt32
        switch method {
        case .backspace(let b, let w, let t):
            (between, wait, textDelay) = (b, w, t)
        case .clearSuggestion(let b, let w, let t):
            (between, wait, textDelay) = (b, w, t)
            if n > 0 {
                type(Self.breaker, delay: 0)
                usleep(max(between, 1000))
                n += 1
            }
        }
        for i in 0..<n {
            if i > 0, between > 0 { usleep(between) }
            tap(Self.backspaceKey)
        }
        if n > 0, !insert.isEmpty { usleep(wait) }
        type(insert, delay: textDelay)
        if let o = original?.copy() {
            if n > 0 || !insert.isEmpty { usleep(max(textDelay, 500)) }
            post(o)
        }
    }
}

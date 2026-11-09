import Foundation

/// Việc cần làm với một phím trong chế độ "app chạy riêng" (Phím Việt Key).
public enum TapAction: Equatable {
    /// Để phím đi tiếp tới ứng dụng như bình thường.
    case pass
    /// Nuốt phím, không gửi gì.
    case consume
    /// Nuốt phím; xoá `delete` ký tự ngay trước con trỏ, gõ `insert`,
    /// rồi (nếu `thenOriginal`) gửi lại chính phím gốc (cách, dấu câu, Enter…).
    case replace(delete: Int, insert: String, thenOriginal: Bool)
}

/// Logic gõ của chế độ app chạy riêng — thuần, không đụng hệ thống (test được).
///
/// Không đọc tài liệu: chỉ nhớ `shown` — chuỗi chính ta đã đưa vào ứng dụng cho từ hiện tại.
/// Mọi thứ có thể làm `shown` sai (click chuột, phím điều hướng, phím tắt, đổi app) đều phải gọi `reset()`.
public final class TapSession {
    public let engine: CompositionEngine
    /// Chữ của từ hiện tại đang nằm trong ứng dụng (ngay trước con trỏ).
    public private(set) var shown = ""
    /// Từ vừa chốt bằng một phím ranh giới 1 ký tự (cách, dấu câu, Enter) — để sửa dấu sau ⌫.
    private var lastWord: String?
    /// ⌫ vừa xoá ký tự ranh giới sau `lastWord` → phím chữ tiếp theo nối vào từ đó.
    private var rewindWord: String?

    public init(engine: CompositionEngine) {
        self.engine = engine
    }

    public var isComposing: Bool { engine.isComposing }

    /// Quên từ đang gõ (con trỏ có thể đã đổi chỗ). Không chạm vào tài liệu.
    public func reset() {
        engine.reset()
        shown = ""
        lastWord = nil
        rewindWord = nil
    }

    /// Số lần ⌫ và chuỗi cần gõ để biến `old` thành `new` (theo ký tự hiển thị — mỗi ⌫ xoá một ký tự).
    public static func diff(_ old: String, _ new: String) -> (delete: Int, insert: String) {
        let common = DirectEdit.commonPrefixCount(old, new)
        return (old.count - common, String(new.dropFirst(common)))
    }

    /// Phím có ký tự (đã áp Shift/Caps Lock theo bố cục bàn phím).
    public func key(_ text: String, shift: Bool, caps: Bool) -> TapAction {
        guard text.unicodeScalars.count == 1, let k = text.unicodeScalars.first else {
            reset()
            return .pass
        }
        lastWord = nil
        if let w = rewindWord {
            rewindWord = nil
            if !engine.isComposing, k.isASCII, CharacterSet.alphanumerics.contains(k), engine.loadWord(w) {
                shown = w
            }
        }
        switch engine.process(k, shift: shift, caps: caps) {
        case .unchanged:
            shown = ""
            return .pass
        case .composing(let t):
            return show(t, typed: text)
        case .commit(let t, let passThrough):
            let old = shown
            shown = ""
            engine.reset()
            // Chỉ nhớ từ khi phím ranh giới tạo đúng 1 ký tự mà ⌫ sẽ xoá (không nhớ Tab: có thể đổi ô).
            if passThrough, !t.isEmpty, k != "\t" { lastWord = t }
            let (d, ins) = Self.diff(old, t)
            if d == 0 && ins.isEmpty { return passThrough ? .pass : .consume }
            return .replace(delete: d, insert: ins, thenOriginal: passThrough)
        }
    }

    public func backspace() -> TapAction {
        if engine.isComposing {
            guard case .composing(let t) = engine.backspace() else {
                reset()
                return .pass
            }
            let expected = String(shown.dropLast())
            let old = shown
            shown = t
            if t == expected { return .pass }  // ứng dụng tự xoá đúng 1 ký tự (giữ undo của app)
            let (d, ins) = Self.diff(old, t)
            return .replace(delete: d, insert: ins, thenOriginal: false)
        }
        // ⌫ ngay sau "từ + ranh giới": ứng dụng xoá ranh giới, phím chữ tiếp theo sửa tiếp từ đó.
        // ⌫ lần thứ hai (hoặc không có từ) → không sửa gì.
        rewindWord = lastWord
        lastWord = nil
        return .pass
    }

    /// ESC: trả lại phím thô đã gõ cho từ hiện tại.
    public func escape() -> TapAction {
        lastWord = nil
        rewindWord = nil
        guard engine.isComposing, case .commit(let raw, _) = engine.restoreRaw() else {
            reset()
            return .pass
        }
        let old = shown
        shown = ""
        engine.reset()
        let (d, ins) = Self.diff(old, raw)
        return .replace(delete: d, insert: ins, thenOriginal: false)
    }

    private func show(_ t: String, typed: String) -> TapAction {
        let old = shown
        shown = t
        if t == old + typed { return .pass }  // đúng phím vừa gõ: để ứng dụng tự chèn
        if t.isEmpty { reset() }
        let (d, ins) = Self.diff(old, t)
        return .replace(delete: d, insert: ins, thenOriginal: false)
    }
}

/// Cách đưa chữ thay thế vào ứng dụng (chế độ app chạy riêng).
public enum InjectionMethod: Equatable {
    /// ⌫ × n rồi gõ chữ; chờ (µs) giữa các ⌫, trước khi gõ, giữa các đoạn chữ.
    case backspace(between: UInt32, wait: UInt32, text: UInt32)
    /// Trình duyệt: gõ trước 1 ký tự vô hình để huỷ phần gợi ý đang bôi đen (thanh địa chỉ), rồi ⌫ × (n+1).
    case clearSuggestion(between: UInt32, wait: UInt32, text: UInt32)

    static let browsers: Set<String> = [
        "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.canary", "org.chromium.Chromium",
        "com.apple.Safari", "com.apple.SafariTechnologyPreview", "org.mozilla.firefox",
        "org.mozilla.firefoxdeveloperedition", "com.microsoft.edgemac", "company.thebrowser.Browser",
        "com.brave.Browser", "com.operasoftware.Opera", "com.vivaldi.Vivaldi", "app.zen-browser.zen",
        "com.kagi.kagimacOS", "com.sigmaos.sigmaos.macos", "ru.yandex.desktop.yandex-browser",
        "com.coccoc.Coccoc",
        // Ô tìm kiếm có gợi ý bôi đen sau con trỏ, giống thanh địa chỉ.
        "com.apple.Spotlight", "com.raycast.macos", "com.runningwithcrayons.Alfred",
    ]
    static let office: Set<String> = [
        "com.microsoft.Word", "com.microsoft.Excel", "com.microsoft.Powerpoint", "com.microsoft.Outlook",
        "com.microsoft.onenote.mac",
    ]
    static let slowPrefixes = [
        "com.microsoft.VSCode", "com.todesktop.", "com.tinyspeck.slackmacgap", "com.hnc.Discord",
        "notion.id", "md.obsidian", "com.jetbrains.", "com.google.android.studio", "com.apple.Terminal",
        "com.googlecode.iterm2", "dev.warp.", "com.mitchellh.ghostty", "net.kovidgoyal.kitty",
        "io.alacritty", "com.github.wez.wezterm", "com.anthropic.claudefordesktop", "com.openai.chat",
        "ru.keepcoder.Telegram", "com.facebook.archon", "net.whatsapp.WhatsApp", "com.electron.",
        "us.zoom.xos", "com.microsoft.teams",
    ]

    /// Chọn cách theo app (không có danh sách nào là bắt buộc — app lạ dùng cách mặc định).
    public static func forApp(_ bundle: String) -> InjectionMethod {
        if browsers.contains(bundle) { return .clearSuggestion(between: 2000, wait: 6000, text: 2000) }
        if office.contains(bundle) { return .backspace(between: 3000, wait: 8000, text: 3000) }
        if slowPrefixes.contains(where: { bundle.hasPrefix($0) }) {
            return .backspace(between: 5000, wait: 12000, text: 5000)
        }
        return .backspace(between: 0, wait: 1000, text: 0)
    }
}

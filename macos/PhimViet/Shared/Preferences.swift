import Foundation

public struct MacroEntry: Codable, Equatable, Hashable, Identifiable {
    public var id = UUID()
    public var key: String
    public var value: String

    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }

    enum CodingKeys: String, CodingKey { case key, value }
}

public enum ToggleShortcut: String, Codable, CaseIterable, Identifiable {
    case ctrlShift, ctrlOption, optionShift, cmdShift, none

    public var id: String { rawValue }

    public var mask: UInt {
        switch self {
        case .ctrlShift: return ModifierToggle.control | ModifierToggle.shift
        case .ctrlOption: return ModifierToggle.control | ModifierToggle.option
        case .optionShift: return ModifierToggle.option | ModifierToggle.shift
        case .cmdShift: return ModifierToggle.command | ModifierToggle.shift
        case .none: return 0
        }
    }

    public var label: String {
        switch self {
        case .ctrlShift: return "⌃ Control + ⇧ Shift"
        case .ctrlOption: return "⌃ Control + ⌥ Option"
        case .optionShift: return "⌥ Option + ⇧ Shift"
        case .cmdShift: return "⌘ Command + ⇧ Shift"
        case .none: return "Không dùng"
        }
    }
}

/// Cài đặt người dùng. Lưu thành một khối JSON trong UserDefaults (khoá `preferences`);
/// khoá thiếu → giá trị mặc định (tương thích khi thêm tuỳ chọn mới).
public struct Preferences: Codable, Equatable {
    public var method = "telex"            // telex | vni | simple_telex
    public var toneStyle = "new"           // new | old
    public var directTyping = true         // gõ không gạch chân
    public var spellCheck = true
    public var autoRestore = true
    public var wAsU = true
    public var brackets = false
    public var macrosEnabled = true
    public var macros: [MacroEntry] = []
    public var toggleShortcut = ToggleShortcut.ctrlShift
    public var rememberPerApp = true
    public var showStatusItem = true
    public var alwaysEnglishApps: [String] = []
    public var alwaysVietnameseApps: [String] = []

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Preferences()
        func v<T: Decodable>(_ k: CodingKeys, _ def: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: k)) ?? def
        }
        method = v(.method, d.method)
        toneStyle = v(.toneStyle, d.toneStyle)
        directTyping = v(.directTyping, d.directTyping)
        spellCheck = v(.spellCheck, d.spellCheck)
        autoRestore = v(.autoRestore, d.autoRestore)
        wAsU = v(.wAsU, d.wAsU)
        brackets = v(.brackets, d.brackets)
        macrosEnabled = v(.macrosEnabled, d.macrosEnabled)
        macros = v(.macros, d.macros)
        toggleShortcut = v(.toggleShortcut, d.toggleShortcut)
        rememberPerApp = v(.rememberPerApp, d.rememberPerApp)
        showStatusItem = v(.showStatusItem, d.showStatusItem)
        alwaysEnglishApps = v(.alwaysEnglishApps, d.alwaysEnglishApps)
        alwaysVietnameseApps = v(.alwaysVietnameseApps, d.alwaysVietnameseApps)
        if !["telex", "vni", "simple_telex"].contains(method) { method = d.method }
        if !["new", "old"].contains(toneStyle) { toneStyle = d.toneStyle }
    }

    /// JSON cấu hình cho engine (`pv_set_config`).
    public func engineConfigJSON() -> String {
        let dict: [String: Any] = [
            "method": method,
            "tone_style": toneStyle,
            "spell_check": spellCheck,
            "auto_restore": autoRestore,
            "w_as_u": wAsU,
            "brackets": brackets,
            "macros_enabled": macrosEnabled,
            "macros": macros.map { ["key": $0.key, "value": $0.value] },
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
              let s = String(data: data, encoding: .utf8)
        else { return "{}" }
        return s
    }
}

/// Nhập/xuất bảng gõ tắt (JSON).
public enum MacroIO {
    /// Xuất: mảng `[{"key": …, "value": …}]` giữ thứ tự.
    public static func export(_ macros: [MacroEntry]) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: macros.map { ["key": $0.key, "value": $0.value] },
            options: [.prettyPrinted, .sortedKeys])
    }

    /// Nhập: nhận mảng `[{"key","value"}]` hoặc object `{"vn": "Việt Nam"}`.
    public static func `import`(_ data: Data) throws -> [MacroEntry] {
        let obj = try JSONSerialization.jsonObject(with: data)
        var out: [MacroEntry] = []
        if let arr = obj as? [[String: Any]] {
            for item in arr {
                if let k = item["key"] as? String, let v = item["value"] as? String {
                    out.append(MacroEntry(key: k, value: v))
                }
            }
        } else if let dict = obj as? [String: Any] {
            for k in dict.keys.sorted() {
                if let v = dict[k] as? String { out.append(MacroEntry(key: k, value: v)) }
            }
        } else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return sanitize(out)
    }

    /// Bỏ khoá rỗng/quá dài, khoá trùng (không phân biệt hoa thường) giữ bản sau cùng.
    public static func sanitize(_ list: [MacroEntry]) -> [MacroEntry] {
        var seen: [String: Int] = [:]
        var out: [MacroEntry] = []
        for var m in list {
            m.key = m.key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !m.key.isEmpty, m.key.count <= 64, m.value.count <= 4096,
                  !m.key.contains(where: { $0.isWhitespace })
            else { continue }
            let k = m.key.lowercased()
            if let i = seen[k] {
                out[i] = m
            } else {
                seen[k] = out.count
                out.append(m)
            }
        }
        return out
    }
}

/// Đọc/ghi cài đặt dùng chung giữa input method và app Cài đặt.
public final class PreferencesStore {
    public static let domain = "com.phimviet.inputmethod.PhimViet"
    public static let changedNotification =
        Notification.Name("com.phimviet.inputmethod.PhimViet.preferencesChanged")

    private let defaults: UserDefaults
    private static let prefsKey = "preferences"
    private static let appModesKey = "appModes"
    private static let defaultModeKey = "defaultVietnamese"

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func load() -> Preferences {
        guard let data = defaults.data(forKey: Self.prefsKey),
              let p = try? JSONDecoder().decode(Preferences.self, from: data)
        else { return Preferences() }
        return p
    }

    public func save(_ p: Preferences) {
        if let data = try? JSONEncoder().encode(p) {
            defaults.set(data, forKey: Self.prefsKey)
        }
    }

    /// Chế độ đã nhớ theo app: bundle id → tiếng Việt?
    public func appModes() -> [String: Bool] {
        (defaults.dictionary(forKey: Self.appModesKey) as? [String: Bool]) ?? [:]
    }

    public func setAppMode(_ bundle: String, vietnamese: Bool) {
        guard !bundle.isEmpty else { return }
        var m = appModes()
        m[bundle] = vietnamese
        if m.count > 500 { m = Dictionary(uniqueKeysWithValues: Array(m.prefix(500))) }
        defaults.set(m, forKey: Self.appModesKey)
    }

    public func clearAppModes() {
        defaults.removeObject(forKey: Self.appModesKey)
    }

    public var defaultVietnamese: Bool {
        get { defaults.object(forKey: Self.defaultModeKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Self.defaultModeKey) }
    }
}

/// Quyết định Việt/Anh cho một app.
public enum ModeResolver {
    public static func isVietnamese(bundle: String, prefs: Preferences, remembered: [String: Bool],
                                    fallback: Bool) -> Bool {
        if prefs.alwaysEnglishApps.contains(bundle) { return false }
        if prefs.alwaysVietnameseApps.contains(bundle) { return true }
        if prefs.rememberPerApp, let v = remembered[bundle] { return v }
        return fallback
    }
}

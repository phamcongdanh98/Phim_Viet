import AppKit
import Combine
import Foundation

/// Mô hình cửa sổ Cài đặt: đọc/ghi domain dùng chung với input method và báo cho nó áp dụng ngay.
final class SettingsModel: ObservableObject {
    static let showTabNotification = Notification.Name("com.phimviet.inputmethod.PhimViet.showTab")

    @Published var prefs: Preferences {
        didSet { if prefs != oldValue && !loading { save() } }
    }
    @Published var tab: String
    @Published var appModes: [String: Bool]
    @Published var message: String?
    /// Dòng đang chọn trong bảng gõ tắt (không dùng `@State`: CLT thiếu plugin SwiftUIMacros).
    @Published var macroSelection = Set<MacroEntry.ID>()

    private let defaults: UserDefaults
    private let store: PreferencesStore
    private var loading = false

    init() {
        defaults = UserDefaults(suiteName: PreferencesStore.domain) ?? .standard
        store = PreferencesStore(defaults: defaults)
        prefs = store.load()
        appModes = store.appModes()
        tab = defaults.string(forKey: "settingsTab") ?? "general"
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(self, selector: #selector(externalChange(_:)),
                        name: PreferencesStore.changedNotification, object: nil,
                        suspensionBehavior: .deliverImmediately)
        dnc.addObserver(self, selector: #selector(showTab(_:)),
                        name: Self.showTabNotification, object: nil,
                        suspensionBehavior: .deliverImmediately)
    }

    @objc private func externalChange(_ n: Notification) {
        if (n.userInfo?["sender"] as? String) == "settings" { return }
        reload()
    }

    @objc private func showTab(_ n: Notification) {
        if let t = n.object as? String { tab = t }
        NSApp.activate(ignoringOtherApps: true)
    }

    func reload() {
        loading = true
        defaults.synchronize()
        prefs = store.load()
        appModes = store.appModes()
        loading = false
    }

    private func save() {
        prefs.macros = MacroIO.sanitizeKeepingDrafts(prefs.macros)
        store.save(prefs)
        defaults.synchronize()
        DistributedNotificationCenter.default().postNotificationName(
            PreferencesStore.changedNotification, object: nil,
            userInfo: ["sender": "settings"], deliverImmediately: true)
    }

    // MARK: gõ tắt

    func addMacro() {
        prefs.macros.append(MacroEntry(key: "", value: ""))
    }

    func removeSelectedMacros() {
        let ids = macroSelection
        prefs.macros.removeAll { ids.contains($0.id) }
        macroSelection.removeAll()
    }

    func importMacros() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            guard data.count < 4 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
            let list = try MacroIO.import(data)
            prefs.macros = MacroIO.sanitize(prefs.macros + list)
            message = "Đã nhập \(list.count) từ tắt."
        } catch {
            message = "Không đọc được file: \(error.localizedDescription)"
        }
    }

    func exportMacros() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "phimviet-gotat.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try MacroIO.export(MacroIO.sanitize(prefs.macros)).write(to: url, options: .atomic)
            message = "Đã xuất \(prefs.macros.count) từ tắt."
        } catch {
            message = "Không ghi được file: \(error.localizedDescription)"
        }
    }

    // MARK: ứng dụng

    /// Chọn một app (.app) và trả bundle id.
    func pickAppBundleID() -> String? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url,
              let id = Bundle(url: url)?.bundleIdentifier
        else { return nil }
        return id
    }

    func addAlwaysEnglish() {
        guard let id = pickAppBundleID() else { return }
        prefs.alwaysVietnameseApps.removeAll { $0 == id }
        if !prefs.alwaysEnglishApps.contains(id) { prefs.alwaysEnglishApps.append(id) }
    }

    func addAlwaysVietnamese() {
        guard let id = pickAppBundleID() else { return }
        prefs.alwaysEnglishApps.removeAll { $0 == id }
        if !prefs.alwaysVietnameseApps.contains(id) { prefs.alwaysVietnameseApps.append(id) }
    }

    func clearRemembered() {
        store.clearAppModes()
        appModes = [:]
        DistributedNotificationCenter.default().postNotificationName(
            PreferencesStore.changedNotification, object: nil,
            userInfo: ["sender": "settings"], deliverImmediately: true)
    }

    static func appName(_ bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: "")
        }
        return bundleID
    }
}

extension MacroIO {
    /// Khi đang sửa trong bảng: giữ dòng chưa nhập xong (khoá rỗng) để người dùng gõ tiếp,
    /// nhưng vẫn loại khoá trùng. Khi lưu sang engine, `engineConfigJSON` + engine tự bỏ khoá rỗng.
    static func sanitizeKeepingDrafts(_ list: [MacroEntry]) -> [MacroEntry] {
        list.map { m in
            var m = m
            m.key = String(m.key.filter { !$0.isWhitespace }.prefix(64))
            if m.value.count > 4096 { m.value = String(m.value.prefix(4096)) }
            return m
        }
    }
}

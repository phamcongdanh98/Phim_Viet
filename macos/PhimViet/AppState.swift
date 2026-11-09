import Carbon
import Cocoa

/// Bản địa hoá: khoá là chuỗi tiếng Việt (ngôn ngữ phát triển), `en.lproj` dịch sang tiếng Anh.
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

/// Trạng thái dùng chung của tiến trình input method.
final class AppState {
    static let shared = AppState()
    /// Cài đặt thay đổi (trong tiến trình).
    static let didChange = Notification.Name("PhimViet.preferencesDidChange")

    let store = PreferencesStore(defaults: .standard)
    private(set) var prefs: Preferences
    let trust = ClientTrust()
    let clicks = ClickMonitor()
    let statusItem = StatusItemController()
    private(set) var activeVietnamese = true
    weak var activeController: PhimVietInputController?

    private init() {
        prefs = store.load()
    }

    func start() {
        clicks.start()
        activeVietnamese = store.defaultVietnamese
        refreshStatusItem()
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(externalChange),
            name: PreferencesStore.changedNotification, object: nil,
            suspensionBehavior: .deliverImmediately)
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(inputSourceChanged),
            name: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String), object: nil,
            suspensionBehavior: .deliverImmediately)
        Log.app.info("started, engine \(RustEngine.version, privacy: .public)")
    }

    @objc private func inputSourceChanged() {
        DispatchQueue.main.async { [weak self] in self?.refreshStatusItem() }
    }

    /// Biểu tượng V/E chỉ hiện khi Phím Việt (input method) đang được chọn — chọn ABC (dùng Phím Việt Key)
    /// thì ẩn, để thanh menu không có hai chữ V.
    private func refreshStatusItem() {
        statusItem.setVisible(prefs.showStatusItem && Self.isSelectedInputSource())
    }

    static func isSelectedInputSource() -> Bool {
        guard let src = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let p = TISGetInputSourceProperty(src, kTISPropertyInputSourceID)
        else { return true }
        let id = Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String
        return id.hasPrefix(Bundle.main.bundleIdentifier ?? "com.phimviet.inputmethod.PhimViet")
    }

    @objc private func externalChange(_ n: Notification) {
        // Không phản ứng với thông báo do chính tiến trình này phát.
        if (n.userInfo?["sender"] as? String) == "ime" { return }
        reload()
    }

    func reload() {
        let old = prefs
        prefs = store.load()
        if prefs.directTyping && !old.directTyping { trust.reset() }
        refreshStatusItem()
        NotificationCenter.default.post(name: Self.didChange, object: nil)
        Log.app.info("preferences reloaded")
    }

    /// Đổi cài đặt từ menu nhập liệu.
    func update(_ change: (inout Preferences) -> Void) {
        let old = prefs
        change(&prefs)
        guard prefs != old else { return }
        if prefs.directTyping && !old.directTyping { trust.reset() }
        store.save(prefs)
        refreshStatusItem()
        NotificationCenter.default.post(name: Self.didChange, object: nil)
        DistributedNotificationCenter.default().postNotificationName(
            PreferencesStore.changedNotification, object: nil,
            userInfo: ["sender": "ime"], deliverImmediately: true)
    }

    func modeChanged(vietnamese: Bool, controller: PhimVietInputController) {
        activeController = controller
        activeVietnamese = vietnamese
        statusItem.update(vietnamese: vietnamese)
    }

    /// Từ thanh menu: đổi chế độ cho app đang dùng.
    func requestMode(vietnamese: Bool) {
        if let c = activeController {
            c.setVietnamese(vietnamese, remember: true)
        } else {
            activeVietnamese = vietnamese
            store.defaultVietnamese = vietnamese
            statusItem.update(vietnamese: vietnamese)
        }
    }

    /// Mở Phím Việt Key (app chạy riêng trong Contents/Helpers). Tiến trình input method này
    /// KHÔNG dùng event tap — chỉ mở app kia; người dùng tự cấp quyền Trợ năng cho app đó.
    func openKeyApp() {
        let url = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/PhimVietKey.app")
        let alert = NSAlert()
        alert.messageText = L("Phím Việt Key — gõ không gạch chân ở mọi app")
        alert.informativeText = L("""
            Phím Việt Key là app chạy riêng (giống OpenKey, EVKey): xoá và gõ lại chữ bằng phím, \
            nên không có gạch chân ở Word, Chrome… nhưng cần quyền Trợ năng (Accessibility).

            Sau khi mở: bật quyền Trợ năng, rồi chọn bàn phím ABC trên thanh menu \
            (Phím Việt Key tự nghỉ khi đang chọn bộ gõ khác, kể cả bản này).
            """)
        alert.addButton(withTitle: L("Mở Phím Việt Key"))
        alert.addButton(withTitle: L("Huỷ"))
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error {
                Log.app.error("open key app failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Mở app Cài đặt (nằm trong Contents/Helpers). `tab`: general | typing | macros | apps | about.
    func openSettings(tab: String?) {
        let url = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/PhimVietSettings.app")
        UserDefaults.standard.set(tab ?? "general", forKey: "settingsTab")
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("com.phimviet.inputmethod.PhimViet.showTab"), object: tab ?? "general",
            userInfo: nil, deliverImmediately: true)
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: cfg) { _, error in
            if let error {
                Log.app.error("open settings failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

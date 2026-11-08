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
        statusItem.setVisible(prefs.showStatusItem)
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(externalChange),
            name: PreferencesStore.changedNotification, object: nil,
            suspensionBehavior: .deliverImmediately)
        Log.app.info("started, engine \(RustEngine.version, privacy: .public)")
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
        statusItem.setVisible(prefs.showStatusItem)
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
        statusItem.setVisible(prefs.showStatusItem)
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

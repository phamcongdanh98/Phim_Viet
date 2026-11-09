import Carbon
import Cocoa
import ServiceManagement

/// Phím Việt Key — chế độ "app chạy riêng" (không gạch chân ở mọi app).
///
/// Chặn phím toàn hệ thống, đưa qua engine, rồi xoá/gõ lại bằng phím giả (giống OpenKey, EVKey, Gõ Nhanh).
/// Cần quyền Trợ năng. Chỉ hoạt động khi nguồn nhập hiện tại là một **bố cục bàn phím** (ABC, US…):
/// nếu đang chọn input method khác (kể cả Phím Việt bản gạch chân) thì tự nghỉ để không gõ chồng.
final class KeyApp: NSObject, NSApplicationDelegate {
    private let defaults = UserDefaults(suiteName: PreferencesStore.domain) ?? .standard
    private lazy var store = PreferencesStore(defaults: defaults)
    private var prefs = Preferences()
    private var session: TapSession!
    private let tap = KeyTap()
    private let injector = Injector()
    private var toggle = ModifierToggle(required: ToggleShortcut.ctrlShift.mask)
    private var vietnamese = true
    private var frontBundle = ""
    /// Nguồn nhập hiện tại là bố cục bàn phím thường (không phải input method khác).
    private var layoutActive = true
    private var statusItem: NSStatusItem?
    private var permissionTimer: Timer?

    private static let navigationKeys: Set<Int64> = [
        123, 124, 125, 126, 115, 119, 116, 121, 117, 114,
        122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111,
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        let me = Bundle.main.bundleIdentifier ?? ""
        if NSRunningApplication.runningApplications(withBundleIdentifier: me).count > 1 {
            NSApp.terminate(nil)
            return
        }
        guard let engine = RustEngine() else {
            Log.app.fault("key: cannot create engine")
            NSApp.terminate(nil)
            return
        }
        session = TapSession(engine: engine)
        loadPreferences()
        frontBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        resolveMode()
        refreshInputSource()

        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(self, selector: #selector(appActivated(_:)),
                       name: NSWorkspace.didActivateApplicationNotification, object: nil)
        let dn = DistributedNotificationCenter.default()
        dn.addObserver(self, selector: #selector(preferencesChanged(_:)),
                       name: PreferencesStore.changedNotification, object: nil,
                       suspensionBehavior: .deliverImmediately)
        dn.addObserver(self, selector: #selector(inputSourceChanged),
                       name: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
                       object: nil, suspensionBehavior: .deliverImmediately)

        tap.handler = { [weak self] type, event in self?.handle(type, event) ?? event }
        buildStatusItem()
        startWhenPermitted(prompt: true)
    }

    // MARK: quyền

    private func startWhenPermitted(prompt: Bool) {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        if AXIsProcessTrustedWithOptions(opts), tap.start() {
            permissionTimer?.invalidate()
            permissionTimer = nil
            Log.app.notice("key: tap started")
            updateStatus()
            return
        }
        updateStatus()
        guard permissionTimer == nil else { return }
        // Chờ người dùng bật quyền trong System Settings.
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self, AXIsProcessTrusted() else { return }
            self.startWhenPermitted(prompt: false)
        }
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
        startWhenPermitted(prompt: true)
    }

    // MARK: sự kiện phím

    private func handle(_ type: CGEventType, _ event: CGEvent) -> CGEvent? {
        switch type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            session.reset()  // con trỏ có thể đã đổi chỗ
            return event
        case .flagsChanged:
            let raw = UInt(event.flags.rawValue)
            if raw & (ModifierToggle.command | ModifierToggle.control | ModifierToggle.option) != 0 {
                session.reset()
            }
            if toggle.flagsChanged(raw), layoutActive {
                setVietnamese(!vietnamese, remember: true)
            }
            return event
        case .keyDown:
            toggle.keyDown()
            return keyDown(event)
        default:
            return event
        }
    }

    private func keyDown(_ event: CGEvent) -> CGEvent? {
        guard layoutActive, vietnamese else {
            session.reset()
            return event
        }
        let flags = event.flags
        if !flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty {
            session.reset()
            return event
        }
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        if Self.navigationKeys.contains(code) {
            session.reset()
            return event
        }
        let action: TapAction
        switch code {
        case 51: action = session.backspace()
        case 53: action = session.escape()
        default:
            var len = 0
            var buf = [UniChar](repeating: 0, count: 8)
            event.keyboardGetUnicodeString(maxStringLength: buf.count, actualStringLength: &len, unicodeString: &buf)
            let s = String(utf16CodeUnits: buf, count: len)
            guard len > 0, let first = s.unicodeScalars.first, !(0xF700...0xF8FF).contains(first.value) else {
                session.reset()
                return event
            }
            action = session.key(s, shift: flags.contains(.maskShift), caps: flags.contains(.maskAlphaShift))
        }
        switch action {
        case .pass:
            return event
        case .consume:
            return nil
        case .replace(let d, let ins, let original):
            injector.replace(delete: d, insert: ins, method: InjectionMethod.forApp(frontBundle),
                             original: original ? event : nil)
            return nil
        }
    }

    // MARK: chế độ, cài đặt

    @objc private func appActivated(_ n: Notification) {
        let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        frontBundle = app?.bundleIdentifier ?? ""
        session.reset()
        resolveMode()
        updateStatus()
    }

    private func resolveMode() {
        vietnamese = ModeResolver.isVietnamese(
            bundle: frontBundle, prefs: prefs, remembered: store.appModes(), fallback: store.defaultVietnamese)
    }

    private func setVietnamese(_ on: Bool, remember: Bool) {
        session.reset()
        vietnamese = on
        if remember {
            if prefs.rememberPerApp { store.setAppMode(frontBundle, vietnamese: on) }
            store.defaultVietnamese = on
        }
        updateStatus()
    }

    @objc private func inputSourceChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshInputSource()
            self?.updateStatus()
        }
    }

    private func refreshInputSource() {
        session?.reset()
        guard let src = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let p = TISGetInputSourceProperty(src, kTISPropertyInputSourceType)
        else {
            layoutActive = false
            return
        }
        let type = Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue()
        layoutActive = CFEqual(type, kTISTypeKeyboardLayout)
    }

    private func loadPreferences() {
        prefs = store.load()
        if !session.engine.setConfig(json: prefs.engineConfigJSON()) {
            Log.app.error("key: engine rejected config")
        }
        toggle.required = prefs.toggleShortcut.mask
        session.reset()
    }

    @objc private func preferencesChanged(_ n: Notification) {
        if (n.userInfo?["sender"] as? String) == "key" { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.loadPreferences()
            self.resolveMode()
            self.updateStatus()
        }
    }

    private func update(_ change: (inout Preferences) -> Void) {
        change(&prefs)
        store.save(prefs)
        loadPreferences()
        DistributedNotificationCenter.default().postNotificationName(
            PreferencesStore.changedNotification, object: nil, userInfo: ["sender": "key"],
            deliverImmediately: true)
        updateStatus()
    }

    // MARK: thanh menu

    private func buildStatusItem() {
        let it = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        it.button?.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
        it.button?.toolTip = "Phím Việt Key"
        statusItem = it
        updateStatus()
    }

    private func updateStatus() {
        guard let it = statusItem else { return }
        let permitted = tap.isRunning
        it.button?.title = !permitted ? "V!" : !layoutActive ? "V–" : (vietnamese ? "V" : "E")
        it.menu = buildMenu(permitted: permitted)
    }

    private func buildMenu(permitted: Bool) -> NSMenu {
        let m = NSMenu()
        func add(_ title: String, _ action: Selector?, on: Bool? = nil) {
            let it = NSMenuItem(title: title, action: action, keyEquivalent: "")
            it.target = self
            if let on { it.state = on ? .on : .off }
            if action == nil { it.isEnabled = false }
            m.addItem(it)
        }
        if !permitted {
            add("⚠︎ Chưa có quyền Trợ năng (Accessibility)", nil)
            add("Mở cài đặt quyền Trợ năng…", #selector(openAccessibilitySettings))
            m.addItem(.separator())
        } else if !layoutActive {
            add("Đang nghỉ: nguồn nhập hiện tại là bộ gõ khác", nil)
            add("Hãy chọn bàn phím ABC trên thanh menu", nil)
            m.addItem(.separator())
        }
        add("Tiếng Việt", #selector(menuVietnamese), on: vietnamese)
        add("Tiếng Anh", #selector(menuEnglish), on: !vietnamese)
        m.addItem(.separator())
        add("Telex", #selector(menuTelex), on: prefs.method == "telex")
        add("VNI", #selector(menuVNI), on: prefs.method == "vni")
        add("Simple Telex", #selector(menuSimpleTelex), on: prefs.method == "simple_telex")
        m.addItem(.separator())
        add("Đặt dấu kiểu mới (hoà, thuỷ)", #selector(menuNewStyle), on: prefs.toneStyle == "new")
        add("Đặt dấu kiểu cũ (hòa, thủy)", #selector(menuOldStyle), on: prefs.toneStyle == "old")
        add("Kiểm tra âm tiết", #selector(menuSpell), on: prefs.spellCheck)
        add("Tự khôi phục tiếng Anh", #selector(menuRestore), on: prefs.autoRestore)
        m.addItem(.separator())
        add("Mở cùng máy", #selector(menuLogin), on: SMAppService.mainApp.status == .enabled)
        add("Cài đặt…", #selector(menuSettings))
        m.addItem(.separator())
        add("Thoát Phím Việt Key", #selector(menuQuit))
        return m
    }

    @objc private func menuVietnamese() { setVietnamese(true, remember: true) }
    @objc private func menuEnglish() { setVietnamese(false, remember: true) }
    @objc private func menuTelex() { update { $0.method = "telex" } }
    @objc private func menuVNI() { update { $0.method = "vni" } }
    @objc private func menuSimpleTelex() { update { $0.method = "simple_telex" } }
    @objc private func menuNewStyle() { update { $0.toneStyle = "new" } }
    @objc private func menuOldStyle() { update { $0.toneStyle = "old" } }
    @objc private func menuSpell() { update { $0.spellCheck.toggle() } }
    @objc private func menuRestore() { update { $0.autoRestore.toggle() } }
    @objc private func menuQuit() { NSApp.terminate(nil) }

    @objc private func menuLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            Log.app.error("key: login item \(error.localizedDescription, privacy: .public)")
        }
        updateStatus()
    }

    /// App Cài đặt nằm cạnh app này (Contents/Helpers của Phím Việt).
    @objc private func menuSettings() {
        let url = Bundle.main.bundleURL.deletingLastPathComponent()
            .appendingPathComponent("PhimVietSettings.app")
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: cfg) { _, error in
            if let error { Log.app.error("key: open settings \(error.localizedDescription, privacy: .public)") }
        }
    }
}

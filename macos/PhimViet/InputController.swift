import Cocoa
import InputMethodKit

/// Một controller cho mỗi client (ô nhập) — IMK tạo/huỷ. Toàn bộ logic chữ nằm trong `CompositionSession`.
@objc(PhimVietInputController)
final class PhimVietInputController: IMKInputController {
    private var session: CompositionSession!
    private var toggle = ModifierToggle(required: ToggleShortcut.ctrlShift.mask)
    private(set) var vietnamese = true
    private var currentBundle = ""

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        super.init(server: server, delegate: delegate, client: inputClient)
        guard let engine = RustEngine() else {
            Log.app.fault("cannot create engine")
            return nil
        }
        session = CompositionSession(engine: engine, trust: AppState.shared.trust)
        session.clickCounter = { AppState.shared.clicks.count }
        // Chỉ tên sự kiện (không có nội dung gõ) → ghi mức notice để `log show` đọc lại được.
        session.onEvent = { event in Log.input.notice("\(event, privacy: .public)") }
        applyPreferences()
        NotificationCenter.default.addObserver(
            self, selector: #selector(preferencesChanged), name: AppState.didChange, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func preferencesChanged() {
        applyPreferences()
        // Danh sách app luôn V / luôn E có thể vừa đổi.
        if !currentBundle.isEmpty {
            let p = AppState.shared.prefs
            if p.alwaysEnglishApps.contains(currentBundle) { setVietnamese(false, remember: false) }
            if p.alwaysVietnameseApps.contains(currentBundle) { setVietnamese(true, remember: false) }
        }
    }

    private func applyPreferences() {
        let p = AppState.shared.prefs
        if !session.engine.setConfig(json: p.engineConfigJSON()) {
            Log.app.error("engine rejected config")
        }
        session.directTypingEnabled = p.directTyping
        toggle.required = p.toggleShortcut.mask
    }

    // MARK: sự kiện

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask([.keyDown, .flagsChanged]).rawValue)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, let client = IMKTextClient(sender) else { return false }
        switch event.type {
        case .flagsChanged:
            // Vừa nhấn ⌘/⌃/⌥ khi đang có từ dở → chốt NGAY, trước khi phím tắt (⌘A, ⌘C…) tới.
            // Nếu đợi tới keyDown, Chrome thấy chữ được chèn trong lúc xử lý phím và bỏ qua phím tắt.
            if session.isComposing,
               !event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
                session.commit(.other, client: client)
            }
            if toggle.flagsChanged(UInt(event.modifierFlags.rawValue)) {
                setVietnamese(!vietnamese, remember: true, client: client)
            }
            return false
        case .keyDown:
            toggle.keyDown()
            return handleKeyDown(event, client: client)
        default:
            return false
        }
    }

    /// Mã phím không sinh ký tự: điều hướng, chức năng — chốt từ rồi để app xử lý.
    private static let navigationKeys: Set<UInt16> = [
        123, 124, 125, 126,          // mũi tên
        115, 119, 116, 121,          // Home, End, PageUp, PageDown
        117,                         // Forward Delete
        114,                         // Help/Insert
        122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, // F1–F12
    ]

    private func handleKeyDown(_ event: NSEvent, client: IMKTextClient) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // Phím tắt của ứng dụng (⌘, ⌃, ⌥): chốt từ đang gõ rồi để ứng dụng xử lý.
        if !flags.intersection([.command, .control, .option]).isEmpty {
            session.commit(.other, client: client)
            return false
        }
        if Self.navigationKeys.contains(event.keyCode) {
            session.commit(.other, client: client)
            return false
        }
        guard vietnamese else { return false }
        switch event.keyCode {
        case 51:  // Backspace
            return session.handleBackspace(client: client)
        case 53:  // Esc
            return session.handleEscape(client: client)
        default:
            break
        }
        guard let chars = event.characters, let first = chars.unicodeScalars.first else {
            session.commit(.other, client: client)
            return false
        }
        if (0xF700...0xF8FF).contains(first.value) {  // phím chức năng dùng vùng Private Use
            session.commit(.other, client: client)
            return false
        }
        return session.handleKey(
            chars, shift: flags.contains(.shift), caps: flags.contains(.capsLock), client: client)
    }

    // MARK: vòng đời

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        guard let client = IMKTextClient(sender) else { return }
        currentBundle = client.bundleIdentifier
        let state = AppState.shared
        vietnamese = ModeResolver.isVietnamese(
            bundle: currentBundle, prefs: state.prefs,
            remembered: state.store.appModes(), fallback: state.store.defaultVietnamese)
        session.activate(client: client)
        state.modeChanged(vietnamese: vietnamese, controller: self)
    }

    override func deactivateServer(_ sender: Any!) {
        session.deactivate(client: IMKTextClient(sender))
        super.deactivateServer(sender)
    }

    override func commitComposition(_ sender: Any!) {
        session.commit(.focus, client: IMKTextClient(sender))
    }

    // MARK: chế độ Việt/Anh

    func setVietnamese(_ on: Bool, remember: Bool, client: IMKTextClient? = nil) {
        session.commit(.other, client: client ?? IMKTextClient(self.client()))
        vietnamese = on
        let state = AppState.shared
        if remember {
            if state.prefs.rememberPerApp { state.store.setAppMode(currentBundle, vietnamese: on) }
            state.store.defaultVietnamese = on
        }
        state.modeChanged(vietnamese: on, controller: self)
        Log.input.info("mode \(on ? "V" : "E", privacy: .public)")
    }

    // MARK: menu nhập liệu

    override func menu() -> NSMenu! {
        let p = AppState.shared.prefs
        let m = NSMenu(title: "Phím Việt")
        func add(_ title: String, _ action: Selector, on: Bool? = nil) {
            let it = NSMenuItem(title: L(title), action: action, keyEquivalent: "")
            it.target = self
            if let on { it.state = on ? .on : .off }
            m.addItem(it)
        }
        add("Tiếng Việt", #selector(menuVietnamese(_:)), on: vietnamese)
        add("Tiếng Anh", #selector(menuEnglish(_:)), on: !vietnamese)
        m.addItem(.separator())
        add("Telex", #selector(menuTelex(_:)), on: p.method == "telex")
        add("VNI", #selector(menuVNI(_:)), on: p.method == "vni")
        add("Simple Telex", #selector(menuSimpleTelex(_:)), on: p.method == "simple_telex")
        m.addItem(.separator())
        add("Đặt dấu kiểu mới (hoà, thuỷ)", #selector(menuNewStyle(_:)), on: p.toneStyle == "new")
        add("Đặt dấu kiểu cũ (hòa, thủy)", #selector(menuOldStyle(_:)), on: p.toneStyle == "old")
        m.addItem(.separator())
        add("Gạch chân chữ đang gõ", #selector(menuDirect(_:)), on: !p.directTyping)
        add("Kiểm tra âm tiết", #selector(menuSpell(_:)), on: p.spellCheck)
        add("Tự khôi phục tiếng Anh", #selector(menuRestore(_:)), on: p.autoRestore)
        m.addItem(.separator())
        add("Gõ tắt…", #selector(menuMacros(_:)))
        add("Cài đặt…", #selector(menuSettings(_:)))
        add("Giới thiệu Phím Việt", #selector(menuAbout(_:)))
        return m
    }

    @objc func menuVietnamese(_ sender: Any?) { setVietnamese(true, remember: true) }
    @objc func menuEnglish(_ sender: Any?) { setVietnamese(false, remember: true) }
    @objc func menuTelex(_ sender: Any?) { AppState.shared.update { $0.method = "telex" } }
    @objc func menuVNI(_ sender: Any?) { AppState.shared.update { $0.method = "vni" } }
    @objc func menuSimpleTelex(_ sender: Any?) { AppState.shared.update { $0.method = "simple_telex" } }
    @objc func menuNewStyle(_ sender: Any?) { AppState.shared.update { $0.toneStyle = "new" } }
    @objc func menuOldStyle(_ sender: Any?) { AppState.shared.update { $0.toneStyle = "old" } }
    @objc func menuDirect(_ sender: Any?) { AppState.shared.update { $0.directTyping.toggle() } }
    @objc func menuSpell(_ sender: Any?) { AppState.shared.update { $0.spellCheck.toggle() } }
    @objc func menuRestore(_ sender: Any?) { AppState.shared.update { $0.autoRestore.toggle() } }
    @objc func menuMacros(_ sender: Any?) { AppState.shared.openSettings(tab: "macros") }
    @objc func menuSettings(_ sender: Any?) { AppState.shared.openSettings(tab: "general") }
    @objc func menuAbout(_ sender: Any?) { AppState.shared.openSettings(tab: "about") }
}

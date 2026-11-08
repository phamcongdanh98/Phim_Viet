import Foundation

/// Điều phối một từ đang gõ: engine ↔ presenter ↔ client.
///
/// - Chọn presenter ở **đầu mỗi từ** và giữ nguyên tới khi chốt.
/// - Direct chỉ dùng cho app đã chứng minh đọc lại đúng (`ClientTrust`); mọi lần thay chữ đều kiểm chứng.
/// - Không kiểm chứng được → bỏ từ (không ghi đè), rút quyền app, coi phím hiện tại là đầu từ mới.
/// - Click chuột giữa từ (đếm qua `clickCounter`) → kết thúc từ trước khi xử lý phím tiếp theo.
public final class CompositionSession {
    public let engine: CompositionEngine
    public let trust: ClientTrust
    /// Tuỳ chọn "Gõ không gạch chân".
    public var directTypingEnabled = true
    /// Số lần click chuột toàn cục (tăng dần).
    public var clickCounter: () -> Int = { 0 }
    /// Nhật ký chẩn đoán — chỉ tên sự kiện, KHÔNG có nội dung gõ.
    public var onEvent: (String) -> Void = { _ in }

    public private(set) var presenter: Presenter?
    private var clicksAtWordStart = 0
    private var clientReadable = true

    public init(engine: CompositionEngine, trust: ClientTrust) {
        self.engine = engine
        self.trust = trust
    }

    public var isComposing: Bool { presenter != nil }

    // MARK: vòng đời

    public func activate(client: TextClient) {
        reset()
        clientReadable = ClientTrust.supportsReading(client)
        onEvent(clientReadable ? "activate.readable" : "activate.unreadable")
    }

    public func deactivate(client: TextClient?) {
        commit(.focus, client: client)
    }

    /// Bỏ trạng thái mà không chạm vào tài liệu.
    public func reset() {
        engine.reset()
        presenter = nil
    }

    // MARK: phím

    /// Phím có ký tự. Trả `true` nếu đã xử lý (không đưa cho ứng dụng).
    public func handleKey(_ text: String, shift: Bool, caps: Bool, client: TextClient) -> Bool {
        guard text.unicodeScalars.count == 1, let key = text.unicodeScalars.first else {
            commit(.other, client: client)
            return false
        }
        endWordIfClicked(client: client)
        let out = engine.process(key, shift: shift, caps: caps)
        return route(out, key: key, shift: shift, caps: caps, client: client, retry: true)
    }

    public func handleBackspace(client: TextClient) -> Bool {
        endWordIfClicked(client: client)
        guard let p = presenter else { return false }
        guard case .composing(let text) = engine.backspace() else {
            reset()
            return false
        }
        if let d = p as? DirectPresenter {
            // Engine luôn xoá đúng 1 ký tự hiển thị cuối → để ứng dụng tự xoá (giữ undo của app).
            if d.appWillDeleteLast(resultingIn: text) {
                if text.isEmpty { presenter = nil }
                return false
            }
            if d.update(text, client: client) {
                if text.isEmpty { presenter = nil }
                return true
            }
            abandonDirect(client: client, event: "direct.backspace.abandon")
            return false
        }
        _ = p.update(text, client: client)
        if text.isEmpty { presenter = nil }
        return true
    }

    public func handleEscape(client: TextClient) -> Bool {
        endWordIfClicked(client: client)
        guard presenter != nil else { return false }
        if case .commit(let text, _) = engine.restoreRaw() {
            finish(text, client: client)
        } else {
            reset()
        }
        return true
    }

    /// Kết thúc từ vì phím điều hướng, phím tắt, click, đổi ô/ứng dụng.
    public func commit(_ boundary: Boundary, client: TextClient?) {
        guard let p = presenter else {
            engine.reset()
            return
        }
        guard let client else {
            reset()
            return
        }
        if clickCounter() != clicksAtWordStart {
            endWordAfterClick(client: client)
            return
        }
        if p.kind == .direct && (boundary == .mouse || boundary == .focus) {
            // Con trỏ có thể đã đổi: không sửa tài liệu nữa.
            p.abandon(client: client)
            reset()
            return
        }
        if case .commit(let text, _) = engine.commit(boundary) {
            finish(text, client: client)
        } else {
            reset()
        }
    }

    // MARK: nội bộ

    private func route(_ out: EngineOutput, key: UnicodeScalar, shift: Bool, caps: Bool,
                       client: TextClient, retry: Bool) -> Bool {
        switch out {
        case .unchanged:
            return false
        case .composing(let text):
            let p = presenter ?? startWord(client: client)
            if p.update(text, client: client) {
                if text.isEmpty { presenter = nil }
                return true
            }
            abandonDirect(client: client, event: "direct.abandon")
            guard retry else { return false }
            // Phím hiện tại là đầu một từ mới.
            let again = engine.process(key, shift: shift, caps: caps)
            return route(again, key: key, shift: shift, caps: caps, client: client, retry: false)
        case .commit(let text, let passThrough):
            finish(text, client: client)
            return !passThrough
        }
    }

    private func startWord(client: TextClient) -> Presenter {
        let bundle = client.bundleIdentifier
        let direct = directTypingEnabled && clientReadable && !bundle.isEmpty
            && trust.allowsDirect(bundle)
        let p: Presenter = direct ? DirectPresenter() : MarkedPresenter()
        presenter = p
        clicksAtWordStart = clickCounter()
        return p
    }

    private func finish(_ text: String, client: TextClient) {
        guard let p = presenter else {
            engine.reset()
            return
        }
        presenter = nil
        let bundle = client.bundleIdentifier
        if !p.commit(text, client: client) {
            trust.revoke(bundle)
            onEvent("direct.commit.abandon")
            return
        }
        // Chứng minh: sau khi chốt bằng Marked, đọc lại tài liệu phải thấy đúng chữ vừa chèn.
        if p.kind == .marked, directTypingEnabled, clientReadable, !bundle.isEmpty, !text.isEmpty,
           trust.state(bundle) == .unknown {
            let ok = ClientTrust.readBack(text, client: client)
            trust.record(bundle, proved: ok)
            onEvent(ok ? "trust.proved" : "trust.failed")
        }
    }

    private func abandonDirect(client: TextClient, event: String) {
        trust.revoke(client.bundleIdentifier)
        onEvent(event)
        presenter = nil
        engine.reset()
    }

    private func endWordIfClicked(client: TextClient) {
        guard presenter != nil, clickCounter() != clicksAtWordStart else { return }
        endWordAfterClick(client: client)
    }

    private func endWordAfterClick(client: TextClient) {
        onEvent("click.endword")
        guard let p = presenter else {
            engine.reset()
            return
        }
        switch p.kind {
        case .direct:
            p.abandon(client: client)
            reset()
        case .marked:
            if case .commit(let text, _) = engine.commit(.mouse) {
                presenter = nil
                p.commit(text, client: client)
            } else {
                reset()
            }
        }
    }
}

import Foundation

/// Điều phối một từ đang gõ: engine ↔ presenter ↔ client.
///
/// - Chọn presenter ở **đầu mỗi từ** và giữ nguyên tới khi chốt.
/// - Direct chỉ dùng cho app đã chứng minh đọc lại đúng (`ClientTrust`); mọi lần ghi đều kiểm chứng.
/// - Không kiểm chứng được trước khi ghi → bỏ từ (không ghi đè), rút quyền app, coi phím hiện tại
///   là đầu từ mới. Kiểm tra sau khi ghi thất bại → kết thúc từ, rút quyền app.
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
    /// Lần ghi cuối của từ vừa chốt (Direct) mà app chưa xác nhận — kiểm ở phím kế tiếp.
    private var leftover: (bundle: String, pending: DirectEdit.Pending, clicks: Int)?
    /// Chứng minh chưa đạt ngay (app báo trễ) — thử lại ở phím kế tiếp.
    private var pendingProof: (bundle: String, text: String, clicks: Int)?
    /// Vừa có Backspace đi qua ranh giới từ → phím chữ tiếp theo có thể sửa dấu cho từ trước.
    private var rewindArmed = false
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

    /// Kiểm lần ghi chưa được xác nhận của từ trước (app báo trễ). Sai → rút quyền gõ trực tiếp.
    private func checkLeftover(client: TextClient) {
        if let pp = pendingProof {
            pendingProof = nil
            if pp.bundle == client.bundleIdentifier, pp.clicks == clickCounter(),
               trust.state(pp.bundle) == .unknown {
                if let pos = ClientTrust.proveLater(pp.text, client: client) {
                    trust.record(pp.bundle, proved: true, position: pos)
                    onEvent("trust.proved.late \(pp.bundle)")
                } else {
                    onEvent("trust.failed \(pp.bundle) \(ClientTrust.diagnose(pp.text, client: client))")
                    trust.record(pp.bundle, proved: false, position: -1)
                }
            }
        }
        guard let l = leftover else { return }
        leftover = nil
        guard l.bundle == client.bundleIdentifier, l.clicks == clickCounter() else { return }
        // slack 2: phím kết thúc từ (cách, dấu câu, xuống dòng) app đã tự chèn.
        if !l.pending.holds(in: client, slack: 2) {
            trust.revoke(l.bundle)
            onEvent("direct.latecheck.failed")
        }
    }

    // MARK: phím

    /// Phím có ký tự. Trả `true` nếu đã xử lý (không đưa cho ứng dụng).
    public func handleKey(_ text: String, shift: Bool, caps: Bool, client: TextClient) -> Bool {
        guard text.unicodeScalars.count == 1, let key = text.unicodeScalars.first else {
            commit(.other, client: client)
            return false
        }
        checkLeftover(client: client)
        endWordIfClicked(client: client)
        if rewindArmed {
            rewindArmed = false
            if presenter == nil { tryRewind(key: key, client: client) }
        }
        let out = engine.process(key, shift: shift, caps: caps)
        return route(out, key: key, shift: shift, caps: caps, client: client, retry: true)
    }

    public func handleBackspace(client: TextClient) -> Bool {
        checkLeftover(client: client)
        endWordIfClicked(client: client)
        guard let p = presenter else {
            rewindArmed = true
            return false
        }
        rewindArmed = false
        guard case .composing(let text) = engine.backspace() else {
            reset()
            return false
        }
        if let d = p as? DirectPresenter {
            // Engine luôn xoá đúng 1 ký tự hiển thị cuối → để ứng dụng tự xoá (giữ undo của app).
            // Chỉ khi không có vùng chọn: có gợi ý bôi đen thì ⌫ của app chỉ xoá phần gợi ý.
            if client.selectedRange().length == 0, d.appWillDeleteLast(resultingIn: text) {
                if text.isEmpty { presenter = nil }
                return false
            }
            switch d.update(text, client: client) {
            case .ok:
                if text.isEmpty { presenter = nil }
                return true
            case .unverified:
                endWordUntrusted(client: client, event: "direct.backspace.unverified")
                return true
            case .abandoned:
                endWordUntrusted(client: client, event: "direct.backspace.abandon")
                return false
            }
        }
        _ = p.update(text, client: client)
        if text.isEmpty { presenter = nil }
        return true
    }

    public func handleEscape(client: TextClient) -> Bool {
        rewindArmed = false
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
        rewindArmed = false
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
            switch p.update(text, client: client) {
            case .ok:
                if text.isEmpty { presenter = nil }
                return true
            case .unverified:
                // Đã ghi nhưng app không xác nhận đúng → dừng ở đây, không ghi thêm.
                endWordUntrusted(client: client, event: "direct.unverified")
                return true
            case .abandoned:
                endWordUntrusted(client: client, event: "direct.abandon")
                guard retry else { return false }
                // Phím hiện tại là đầu một từ mới.
                let again = engine.process(key, shift: shift, caps: caps)
                return route(again, key: key, shift: shift, caps: caps, client: client, retry: false)
            }
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
        if p.commit(text, client: client) != .ok {
            trust.revoke(bundle)
            onEvent("direct.commit.unverified")
            return
        }
        if let d = p as? DirectPresenter, let pend = d.pending {
            leftover = (bundle, pend, clickCounter())
        }
        // Chứng minh: sau khi chốt bằng Marked, con trỏ phải ở cuối chữ vừa chèn và đọc lại đúng chữ đó.
        if p.kind == .marked, directTypingEnabled, clientReadable, !bundle.isEmpty, !text.isEmpty,
           trust.state(bundle) == .unknown {
            if let pos = ClientTrust.proveAfterCommit(text, client: client) {
                trust.record(bundle, proved: true, position: pos)
                onEvent("trust.proved \(bundle)")
            } else {
                // App có thể báo vị trí con trỏ trễ (Chrome): thử lại ở phím kế tiếp.
                pendingProof = (bundle, text, clickCounter())
                onEvent("trust.deferred \(bundle) \(ClientTrust.diagnose(text, client: client))")
            }
        }
    }

    /// Sửa dấu cho từ ngay trước con trỏ (sau khi Backspace xoá dấu cách): nạp từ đó vào engine
    /// và tiếp tục bằng Direct. Chỉ cho app đã được tin; mọi lần thay vẫn được kiểm chứng như thường.
    private func tryRewind(key: UnicodeScalar, client: TextClient) {
        let bundle = client.bundleIdentifier
        guard directTypingEnabled, clientReadable, !bundle.isEmpty, trust.allowsDirect(bundle),
              key.isASCII, CharacterSet.alphanumerics.contains(key)
        else { return }
        let sel = client.selectedRange()
        guard sel.location != NSNotFound, sel.length == 0, sel.location > 0 else { return }
        let k = min(sel.location, 33)
        guard let before = client.text(in: NSRange(location: sel.location - k, length: k)) else { return }
        var word = ""
        for ch in before.reversed() {
            guard ch.isLetter, ch.unicodeScalars.count == 1 else { break }
            word.insert(ch, at: word.startIndex)
        }
        // Có ranh giới trước từ (hoặc từ bắt đầu tài liệu) — không lấy nửa từ.
        guard !word.isEmpty, word.utf16.count < k || sel.location == word.utf16.count else { return }
        guard engine.loadWord(word) else { return }
        presenter = DirectPresenter(continuing: word)
        clicksAtWordStart = clickCounter()
        onEvent("rewind n=\(word.utf16.count)")
    }

    private func endWordUntrusted(client: TextClient, event: String) {
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
            // App có thể đã tự chốt marked text khi click (không gọi commitComposition):
            // chèn lại sẽ nhân đôi chữ → chỉ chốt khi vẫn còn marked text.
            let m = client.markedRange()
            guard m.location != NSNotFound, m.length > 0,
                  case .commit(let text, _) = engine.commit(.mouse)
            else {
                onEvent("click.marked.gone")
                reset()
                return
            }
            presenter = nil
            p.commit(text, client: client)
        }
    }
}

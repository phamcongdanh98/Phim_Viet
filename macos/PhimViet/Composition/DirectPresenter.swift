import Foundation

/// "Gõ không gạch chân": ghi thẳng vào tài liệu qua `DirectEdit`, chỉ nhớ `shown`.
public final class DirectPresenter: Presenter {
    public let kind = PresenterKind.direct
    public private(set) var shown = ""
    /// Kết quả lần sửa gần nhất (để chẩn đoán / test).
    public private(set) var lastOutcome: DirectEdit.Outcome = .unchanged
    /// Lần ghi chưa được app xác nhận (báo trễ), kiểm ở lần sửa sau.
    public private(set) var pending: DirectEdit.Pending?

    public init() {}

    private static func result(_ r: DirectEdit.Outcome) -> PresentResult {
        switch r {
        case .abandoned: return .abandoned
        case .unverified: return .unverified
        default: return .ok
        }
    }

    public func update(_ text: String, client: TextClient) -> PresentResult {
        let (r, p) = DirectEdit.edit(from: shown, to: text, client: client, pending: pending)
        lastOutcome = r
        let res = Self.result(r)
        shown = res == .ok ? text : ""
        pending = res == .ok ? p : nil
        return res
    }

    @discardableResult
    public func commit(_ text: String, client: TextClient) -> PresentResult {
        let (r, p) = DirectEdit.edit(from: shown, to: text, client: client, pending: pending)
        lastOutcome = r
        shown = ""
        let res = Self.result(r)
        pending = res == .ok ? p : nil
        return res
    }

    public func abandon(client: TextClient) {
        shown = ""
        pending = nil
    }

    /// Ứng dụng sẽ tự xoá 1 ký tự cuối (phím Backspace được trả cho app).
    /// Chỉ hợp lệ khi `text` đúng bằng `shown` bỏ ký tự cuối.
    public func appWillDeleteLast(resultingIn text: String) -> Bool {
        guard !shown.isEmpty, String(shown.dropLast()).utf16Equals(text) else { return false }
        if let p = pending {
            let removed = shown.utf16.count - text.utf16.count
            pending = DirectEdit.Pending(caret: p.caret - removed, start: p.start, text: text)
        }
        shown = text
        return true
    }
}

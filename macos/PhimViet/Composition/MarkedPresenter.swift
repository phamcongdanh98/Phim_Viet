import Foundation

public enum PresenterKind: Equatable {
    case marked
    case direct
}

/// Kết quả hiển thị/chốt của presenter.
public enum PresentResult: Equatable {
    case ok
    /// Không kiểm chứng được → không ghi gì (Direct).
    case abandoned
    /// Đã ghi nhưng kiểm tra sau khi ghi thất bại (Direct) → kết thúc từ, rút quyền app.
    case unverified
}

/// Cách hiển thị chữ đang gõ của một từ.
public protocol Presenter: AnyObject {
    var kind: PresenterKind { get }
    /// Chuỗi đang hiển thị cho từ hiện tại.
    var shown: String { get }
    /// Hiển thị chuỗi mới.
    func update(_ text: String, client: TextClient) -> PresentResult
    /// Chốt từ bằng `text`.
    @discardableResult
    func commit(_ text: String, client: TextClient) -> PresentResult
    /// Kết thúc từ mà không sửa thêm tài liệu (Direct) / chốt chữ đang hiển thị (Marked).
    func abandon(client: TextClient)
}

/// Đường an toàn: `setMarkedText` khi đang gõ, `insertText` khi chốt.
public final class MarkedPresenter: Presenter {
    public let kind = PresenterKind.marked
    public private(set) var shown = ""

    public init() {}

    public func update(_ text: String, client: TextClient) -> PresentResult {
        client.setMarkedText(
            text,
            selectionRange: NSRange(location: text.utf16.count, length: 0),
            replacementRange: notFoundRange
        )
        shown = text
        return .ok
    }

    @discardableResult
    public func commit(_ text: String, client: TextClient) -> PresentResult {
        if text.isEmpty {
            if !shown.isEmpty {
                client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0),
                                     replacementRange: notFoundRange)
            }
        } else {
            client.insertText(text, replacementRange: notFoundRange)
        }
        shown = ""
        return .ok
    }

    public func abandon(client: TextClient) {
        commit(shown, client: client)
    }
}

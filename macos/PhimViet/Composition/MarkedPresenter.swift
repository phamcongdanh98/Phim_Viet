import Foundation

public enum PresenterKind: Equatable {
    case marked
    case direct
}

/// Cách hiển thị chữ đang gõ của một từ.
public protocol Presenter: AnyObject {
    var kind: PresenterKind { get }
    /// Chuỗi đang hiển thị cho từ hiện tại.
    var shown: String { get }
    /// Hiển thị chuỗi mới. `false` → presenter đã bỏ từ (không ghi gì).
    func update(_ text: String, client: TextClient) -> Bool
    /// Chốt từ bằng `text`. `false` → không áp dụng được (chữ trong tài liệu giữ nguyên như đang hiển thị).
    @discardableResult
    func commit(_ text: String, client: TextClient) -> Bool
    /// Kết thúc từ mà không sửa thêm tài liệu (Direct) / chốt chữ đang hiển thị (Marked).
    func abandon(client: TextClient)
}

/// Đường an toàn: `setMarkedText` khi đang gõ, `insertText` khi chốt.
public final class MarkedPresenter: Presenter {
    public let kind = PresenterKind.marked
    public private(set) var shown = ""

    public init() {}

    public func update(_ text: String, client: TextClient) -> Bool {
        client.setMarkedText(
            text,
            selectionRange: NSRange(location: text.utf16.count, length: 0),
            replacementRange: notFoundRange
        )
        shown = text
        return true
    }

    @discardableResult
    public func commit(_ text: String, client: TextClient) -> Bool {
        if text.isEmpty {
            if !shown.isEmpty {
                client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0),
                                     replacementRange: notFoundRange)
            }
        } else {
            client.insertText(text, replacementRange: notFoundRange)
        }
        shown = ""
        return true
    }

    public func abandon(client: TextClient) {
        commit(shown, client: client)
    }
}

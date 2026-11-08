import Cocoa
import InputMethodKit

/// Adapter từ client IMK (`IMKTextInput`) sang `TextClient` của PhimVietKit.
final class IMKTextClient: TextClient {
    private let client: IMKTextInput & NSObjectProtocol
    let bundleIdentifier: String

    init?(_ sender: Any?) {
        guard let c = sender as? (IMKTextInput & NSObjectProtocol) else { return nil }
        client = c
        bundleIdentifier = c.bundleIdentifier() ?? ""
    }

    func selectedRange() -> NSRange { client.selectedRange() }
    func markedRange() -> NSRange { client.markedRange() }

    func documentLength() -> Int? {
        let n = client.length()
        return n >= 0 ? n : nil
    }

    func text(in range: NSRange) -> String? {
        var actual = range
        if let s = client.string(from: range, actualRange: &actual) {
            // Client tự co/dời vùng → không dùng được để kiểm chứng.
            guard actual.location == range.location, actual.length == range.length else { return nil }
            return s
        }
        return client.attributedSubstring(from: range)?.string
    }

    func insertText(_ text: String, replacementRange: NSRange) {
        client.insertText(text, replacementRange: replacementRange)
    }

    func setMarkedText(_ text: String, selectionRange: NSRange, replacementRange: NSRange) {
        client.setMarkedText(text, selectionRange: selectionRange, replacementRange: replacementRange)
    }
}

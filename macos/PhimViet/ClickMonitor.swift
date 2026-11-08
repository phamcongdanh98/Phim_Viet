import Cocoa

/// Đếm click chuột toàn cục. IMK không báo click khi không có marked text (gõ trực tiếp),
/// nên đầu mỗi phím `CompositionSession` so số click để biết con trỏ có thể đã đổi.
/// Theo dõi sự kiện chuột toàn cục KHÔNG cần quyền Accessibility (chỉ sự kiện phím mới cần).
final class ClickMonitor {
    private(set) var count = 0
    private var monitor: Any?

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            self?.count &+= 1
        }
    }

    func stop() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
    }
}

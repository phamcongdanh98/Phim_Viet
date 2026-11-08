import Cocoa
import InputMethodKit

// Điểm vào của input method: tạo IMKServer rồi chạy NSApplication (LSBackgroundOnly).
// KHÔNG dùng event tap, KHÔNG gửi phím giả, KHÔNG cần quyền Trợ năng (Accessibility).

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppState.shared.start()
    }
}

let connectionName = (Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String)
    ?? "com.phimviet.inputmethod.PhimViet_Connection"

guard let server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier) else {
    Log.app.fault("cannot create IMKServer")
    exit(1)
}
_ = server  // giữ server sống suốt tiến trình

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()

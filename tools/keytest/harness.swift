import Cocoa
// Ô nhập test: ghi từng keyDown (mã phím, ký tự) và nội dung sau mỗi thay đổi vào file log.
let logPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/pv_harness.log"
FileManager.default.createFile(atPath: logPath, contents: nil)
let fh = FileHandle(forWritingAtPath: logPath)!
func log(_ s: String) { fh.write((s + "\n").data(using: .utf8)!) }
final class TV: NSTextView {
    override func keyDown(with e: NSEvent) {
        let c = e.characters ?? ""
        log("key code=\(e.keyCode) chars=\(c.unicodeScalars.map { String(format: "%04X", $0.value) }.joined(separator: ",")) flags=\(e.modifierFlags.rawValue)")
        super.keyDown(with: e)
        log("text=[\(string)]")
    }
}
final class D: NSObject, NSApplicationDelegate {
    var w: NSWindow!
    func applicationDidFinishLaunching(_ n: Notification) {
        w = NSWindow(contentRect: NSRect(x: 200, y: 300, width: 520, height: 160), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "PV Harness"
        let tv = TV(frame: w.contentView!.bounds)
        tv.isAutomaticTextCompletionEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.font = NSFont.systemFont(ofSize: 20)
        w.contentView!.addSubview(tv)
        w.makeKeyAndOrderFront(nil)
        w.makeFirstResponder(tv)
        NSApp.activate(ignoringOtherApps: true)
        log("pid=\(getpid())")
    }
}
let d = D()
NSApplication.shared.delegate = d
NSApplication.shared.setActivationPolicy(.regular)
NSApplication.shared.run()

import Cocoa

// Phím Việt Key: app chạy riêng trên thanh menu (LSUIElement). Xem KeyApp.swift.
let args = CommandLine.arguments
if args.count >= 2, args[1] == "--selftest" {
    exit(SelfTest.run(Array(args.dropFirst(2))))
}
let delegate = KeyApp()
NSApplication.shared.delegate = delegate
NSApplication.shared.setActivationPolicy(.accessory)
NSApplication.shared.run()

import Cocoa

// Phím Việt Key: app chạy riêng trên thanh menu (LSUIElement). Xem KeyApp.swift.
let delegate = KeyApp()
NSApplication.shared.delegate = delegate
NSApplication.shared.setActivationPolicy(.accessory)
NSApplication.shared.run()

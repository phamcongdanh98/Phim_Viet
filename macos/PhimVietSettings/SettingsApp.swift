import SwiftUI

@main
struct PhimVietSettingsApp: App {
    @StateObject private var model = SettingsModel()
    @NSApplicationDelegateAdaptor(SettingsAppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup("Cài đặt Phím Việt") {
            SettingsView(model: model)
        }
        .windowResizability(.contentMinSize)
    }
}

final class SettingsAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

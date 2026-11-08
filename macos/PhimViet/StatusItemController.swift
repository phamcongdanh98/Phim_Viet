import Cocoa

/// Biểu tượng "V"/"E" trên thanh menu (tuỳ chọn, mặc định bật).
final class StatusItemController: NSObject {
    private var item: NSStatusItem?

    func setVisible(_ visible: Bool) {
        if visible, item == nil {
            let it = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            it.button?.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
            it.button?.toolTip = "Phím Việt"
            it.menu = buildMenu()
            item = it
            update(vietnamese: AppState.shared.activeVietnamese)
        } else if !visible, let it = item {
            NSStatusBar.system.removeStatusItem(it)
            item = nil
        }
    }

    func update(vietnamese: Bool) {
        item?.button?.title = vietnamese ? "V" : "E"
        item?.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let m = NSMenu()
        let vn = AppState.shared.activeVietnamese
        let v = NSMenuItem(title: L("Tiếng Việt"), action: #selector(selectVietnamese), keyEquivalent: "")
        v.state = vn ? .on : .off
        v.target = self
        let e = NSMenuItem(title: L("Tiếng Anh"), action: #selector(selectEnglish), keyEquivalent: "")
        e.state = vn ? .off : .on
        e.target = self
        m.addItem(v)
        m.addItem(e)
        m.addItem(.separator())
        let s = NSMenuItem(title: L("Cài đặt…"), action: #selector(openSettings), keyEquivalent: "")
        s.target = self
        m.addItem(s)
        return m
    }

    @objc private func selectVietnamese() { AppState.shared.requestMode(vietnamese: true) }
    @objc private func selectEnglish() { AppState.shared.requestMode(vietnamese: false) }
    @objc private func openSettings() { AppState.shared.openSettings(tab: nil) }
}

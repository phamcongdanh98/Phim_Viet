import Foundation
import Testing
@testable import PhimVietKit

@Suite("ClientTrust")
struct TrustTests {
    @Test func lifecycle() {
        let t = ClientTrust()
        #expect(t.state("a") == .unknown)
        #expect(!t.allowsDirect("a"))
        t.record("a", proved: true)
        #expect(t.allowsDirect("a"))
        t.revoke("a")
        #expect(t.state("a") == .distrusted)
        t.record("a", proved: true)  // đã mất quyền thì không tự lấy lại trong phiên
        #expect(!t.allowsDirect("a"))
        t.reset()
        #expect(t.state("a") == .unknown)
    }

    @Test func readBack() {
        let c = FakeClient()
        c.doc.setString("xin chào")
        c.sel = NSRange(location: 8, length: 0)
        #expect(ClientTrust.readBack("chào", client: c))
        #expect(!ClientTrust.readBack("chao", client: c))
        c.readable = false
        #expect(!ClientTrust.readBack("chào", client: c))
    }
}

@Suite("ModifierToggle")
struct ToggleTests {
    let ctrl = ModifierToggle.control, shift = ModifierToggle.shift, cmd = ModifierToggle.command

    /// Gửi lần lượt các trạng thái cờ, trả về các lần kích hoạt.
    func run(_ t: inout ModifierToggle, _ seq: [UInt]) -> [Bool] {
        seq.map { t.flagsChanged($0) }
    }

    @Test func pressAndReleaseFires() {
        var t = ModifierToggle(required: ctrl | shift)
        // ⌃ → ⌃⇧ → nhả ⇧ → nhả ⌃
        #expect(run(&t, [ctrl, ctrl | shift, ctrl, 0, 0]) == [false, false, false, true, false])
    }

    @Test func keyInBetweenCancels() {
        var t = ModifierToggle(required: ctrl | shift)
        _ = run(&t, [ctrl | shift])
        t.keyDown()  // ⌃⇧+Tab chẳng hạn
        #expect(run(&t, [0]) == [false])
    }

    @Test func extraModifierCancels() {
        var t = ModifierToggle(required: ctrl | shift)
        #expect(run(&t, [ctrl | shift | cmd, ctrl | shift | cmd, 0]) == [false, false, false])
        var u = ModifierToggle(required: ctrl | shift)
        #expect(run(&u, [ctrl | shift, ctrl | shift | cmd, ctrl, 0]) == [false, false, false, false])
    }

    @Test func capsLockIgnoredAndDisabled() {
        var t = ModifierToggle(required: ctrl | shift)
        #expect(run(&t, [ctrl | shift | (1 << 16), 1 << 16]) == [false, true])
        var off = ModifierToggle(required: 0)
        #expect(run(&off, [ctrl | shift, 0]) == [false, false])
    }
}

@Suite("Preferences")
struct PreferencesTests {
    @Test func decodesWithDefaultsForMissingKeys() throws {
        let p = try JSONDecoder().decode(Preferences.self, from: Data(#"{"method":"vni","bogus":1}"#.utf8))
        #expect(p.method == "vni")
        #expect(p.directTyping)
        #expect(p.toggleShortcut == .ctrlShift)
        let bad = try JSONDecoder().decode(Preferences.self, from: Data(#"{"method":"xx","toneStyle":3}"#.utf8))
        #expect(bad.method == "telex")
        #expect(bad.toneStyle == "new")
    }

    @Test func engineJSONIsAcceptedByEngine() {
        var p = Preferences()
        p.method = "vni"
        p.macros = [MacroEntry(key: "vn", value: "Việt \"Nam\"")]
        let e = RustEngine()!
        #expect(e.setConfig(json: p.engineConfigJSON()))
        _ = e.process("v", shift: false, caps: false)
        _ = e.process("n", shift: false, caps: false)
        #expect(e.commit(.space) == .commit("Việt \"Nam\"", passThrough: true))
        #expect(!e.setConfig(json: "{"))
    }

    @Test func storeRoundTrip() {
        let d = UserDefaults(suiteName: "phimviet.tests.\(UUID().uuidString)")!
        let s = PreferencesStore(defaults: d)
        var p = s.load()
        #expect(p == Preferences())
        p.toneStyle = "old"
        p.alwaysEnglishApps = ["com.apple.Terminal"]
        s.save(p)
        #expect(s.load() == p)
        s.setAppMode("com.a", vietnamese: false)
        #expect(s.appModes()["com.a"] == false)
        #expect(s.defaultVietnamese)
    }

    @Test func modeResolver() {
        var p = Preferences()
        p.alwaysEnglishApps = ["term"]
        p.alwaysVietnameseApps = ["notes"]
        #expect(!ModeResolver.isVietnamese(bundle: "term", prefs: p, remembered: ["term": true], fallback: true))
        #expect(ModeResolver.isVietnamese(bundle: "notes", prefs: p, remembered: ["notes": false], fallback: false))
        #expect(!ModeResolver.isVietnamese(bundle: "x", prefs: p, remembered: ["x": false], fallback: true))
        p.rememberPerApp = false
        #expect(ModeResolver.isVietnamese(bundle: "x", prefs: p, remembered: ["x": false], fallback: true))
    }

    @Test func macroImportExport() throws {
        let list = [MacroEntry(key: "vn", value: "Việt Nam"), MacroEntry(key: "hn", value: "Hà Nội")]
        let back = try MacroIO.import(MacroIO.export(list))
        #expect(back.map(\.key) == ["vn", "hn"])
        let obj = try MacroIO.import(Data(#"{"ko":"không","VN":"x","vn":"y"," ":"z"}"#.utf8))
        #expect(obj.map(\.key).sorted() == ["ko", "vn"] || obj.map(\.key).sorted() == ["VN", "ko"])
        #expect(throws: (any Error).self) { try MacroIO.import(Data("42".utf8)) }
    }
}

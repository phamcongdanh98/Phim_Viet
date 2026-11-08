// Tiện ích nhỏ đăng ký / bật / tắt input source qua Text Input Sources (Carbon).
//   pv-register register <đường-dẫn.app> [--select]
//   pv-register disable <bundle-id>
//   pv-register status <bundle-id>
import Carbon
import Foundation

func sources(bundleID: String) -> [TISInputSource] {
    let filter = [kTISPropertyBundleID as String: bundleID] as CFDictionary
    guard let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource] else {
        return []
    }
    return list
}

func prop<T>(_ s: TISInputSource, _ key: CFString) -> T? {
    guard let p = TISGetInputSourceProperty(s, key) else { return nil }
    return Unmanaged<AnyObject>.fromOpaque(p).takeUnretainedValue() as? T
}

func describe(_ s: TISInputSource) -> String {
    let id: String = prop(s, kTISPropertyInputSourceID) ?? "?"
    let enabled: Bool = prop(s, kTISPropertyInputSourceIsEnabled) ?? false
    let selected: Bool = prop(s, kTISPropertyInputSourceIsSelected) ?? false
    return "\(id) enabled=\(enabled) selected=\(selected)"
}

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("dùng: pv-register register <app> [--select] | disable <bundle-id> | status <bundle-id>")
    exit(2)
}

switch args[1] {
case "register":
    let url = URL(fileURLWithPath: args[2]) as CFURL
    let st = TISRegisterInputSource(url)
    guard st == noErr else {
        print("TISRegisterInputSource lỗi \(st)")
        exit(1)
    }
    let bid = Bundle(url: url as URL)?.bundleIdentifier ?? "com.phimviet.inputmethod.PhimViet"
    let list = sources(bundleID: bid)
    if list.isEmpty { print("đã đăng ký; chưa thấy input source (có thể cần đăng xuất/đăng nhập)") }
    for s in list {
        let e = TISEnableInputSource(s)
        print("bật \(describe(s)) → \(e == noErr ? "OK" : "lỗi \(e)")")
    }
    if args.contains("--select") {
        for s in list {
            let id: String = prop(s, kTISPropertyInputSourceID) ?? ""
            let selectable: Bool = prop(s, kTISPropertyInputSourceIsSelectCapable) ?? false
            if selectable && id.hasSuffix(".vi") {
                print("chọn \(id) → \(TISSelectInputSource(s) == noErr ? "OK" : "lỗi")")
            }
        }
    }
case "disable":
    for s in sources(bundleID: args[2]) {
        print("tắt \(describe(s)) → \(TISDisableInputSource(s) == noErr ? "OK" : "lỗi")")
    }
case "status":
    let list = sources(bundleID: args[2])
    if list.isEmpty { print("không tìm thấy input source cho \(args[2])"); exit(1) }
    list.forEach { print(describe($0)) }
default:
    print("lệnh lạ: \(args[1])")
    exit(2)
}

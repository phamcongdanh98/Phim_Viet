// Vẽ biểu tượng ứng dụng Phím Việt (.icns) bằng mã — không cần file ảnh.
//   swiftc scripts/make_app_icon.swift -o build/make_app_icon
//   build/make_app_icon <main|key|settings> <ra.icns>
// Thiết kế: khối vuông bo góc nền đỏ chuyển sắc + sao vàng; ở giữa là một phím bàn phím trắng in chữ "Ệ"
// (đủ dấu mũ và dấu nặng — đặc trưng tiếng Việt). Key: thêm huy hiệu tia sét; Cài đặt: huy hiệu bánh răng.
import AppKit

let args = CommandLine.arguments
guard args.count == 3, ["main", "key", "settings"].contains(args[1]) else {
    FileHandle.standardError.write("dùng: make_app_icon <main|key|settings> <ra.icns>\n".data(using: .utf8)!)
    exit(2)
}
let variant = args[1]
let output = URL(fileURLWithPath: args[2])

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func star(center: CGPoint, outer: CGFloat, inner: CGFloat) -> CGPath {
    let p = CGMutablePath()
    for i in 0..<10 {
        let r = i % 2 == 0 ? outer : inner
        let a = CGFloat.pi / 2 + CGFloat(i) * .pi / 5
        let pt = CGPoint(x: center.x + r * cos(a), y: center.y + r * sin(a))
        i == 0 ? p.move(to: pt) : p.addLine(to: pt)
    }
    p.closeSubpath()
    return p
}

/// Vẽ toàn bộ biểu tượng trên khung 1024×1024 (gốc toạ độ dưới-trái).
func draw(_ c: CGContext) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    // Khối nền theo lưới biểu tượng macOS: 824×824, lề 100, bo góc ~185.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0x000000, 0.35))
    c.addPath(bodyPath)
    c.setFillColor(rgb(0xC62828))
    c.fillPath()
    c.restoreGState()

    c.saveGState()
    c.addPath(bodyPath)
    c.clip()
    let bg = CGGradient(colorsSpace: space, colors: [rgb(0xF0483E), rgb(0xD32F2F), rgb(0x9E1B1B)] as CFArray,
                        locations: [0, 0.55, 1])!
    c.drawLinearGradient(bg, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    // Ánh sáng mềm phía trên.
    let gloss = CGGradient(colorsSpace: space, colors: [rgb(0xFFFFFF, 0.18), rgb(0xFFFFFF, 0)] as CFArray,
                           locations: [0, 1])!
    c.drawRadialGradient(gloss, startCenter: CGPoint(x: 512, y: 980), startRadius: 0,
                         endCenter: CGPoint(x: 512, y: 980), endRadius: 620, options: [])
    // Sao vàng góc trên phải.
    c.addPath(star(center: CGPoint(x: 790, y: 790), outer: 62, inner: 25))
    c.setFillColor(rgb(0xFFD54F))
    c.fillPath()
    c.restoreGState()

    // Phím bàn phím: phần đáy (độ sâu) + mặt phím.
    let keyBase = CGRect(x: 232, y: 196, width: 560, height: 560)
    let keyTop = CGRect(x: 252, y: 244, width: 520, height: 500)
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -18), blur: 36, color: rgb(0x5A0E0E, 0.55))
    c.addPath(CGPath(roundedRect: keyBase, cornerWidth: 118, cornerHeight: 118, transform: nil))
    c.setFillColor(rgb(0xD8CBC6))
    c.fillPath()
    c.restoreGState()
    c.saveGState()
    c.addPath(CGPath(roundedRect: keyTop, cornerWidth: 104, cornerHeight: 104, transform: nil))
    c.clip()
    let face = CGGradient(colorsSpace: space, colors: [rgb(0xFFFFFF), rgb(0xF3ECE9)] as CFArray,
                          locations: [0, 1])!
    c.drawLinearGradient(face, start: CGPoint(x: 512, y: keyTop.maxY), end: CGPoint(x: 512, y: keyTop.minY),
                         options: [])
    c.restoreGState()

    // Chữ "Ệ".
    let ns = NSGraphicsContext(cgContext: c, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ns
    // Căn giữa theo phần mực thật của chữ (tính cả dấu mũ và dấu nặng), không theo khung dòng chữ.
    var font = NSFont.systemFont(ofSize: 300, weight: .heavy)
    if let d = font.fontDescriptor.withDesign(.rounded), let f = NSFont(descriptor: d, size: 300) { font = f }
    let text = NSAttributedString(string: "Ệ", attributes: [.font: font, .foregroundColor: NSColor(cgColor: rgb(0xC62828))!])
    let line = CTLineCreateWithAttributedString(text)
    c.textMatrix = .identity
    let ink = CTLineGetImageBounds(line, c)
    c.textPosition = CGPoint(x: keyTop.midX - ink.midX, y: keyTop.midY - ink.midY)
    CTLineDraw(line, c)

    // Huy hiệu cho Phím Việt Key / Cài đặt.
    if variant != "main" {
        let center = CGPoint(x: 786, y: 236)
        let r: CGFloat = 118
        c.saveGState()
        c.setShadow(offset: CGSize(width: 0, height: -8), blur: 20, color: rgb(0x000000, 0.35))
        c.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r))
        c.setFillColor(variant == "key" ? rgb(0xFFC107) : rgb(0x455A64))
        c.fillPath()
        c.restoreGState()
        c.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r))
        c.setStrokeColor(rgb(0xFFFFFF))
        c.setLineWidth(12)
        c.strokePath()
        let name = variant == "key" ? "bolt.fill" : "gearshape.fill"
        let cfg = NSImage.SymbolConfiguration(pointSize: 130, weight: .bold)
            .applying(.init(paletteColors: [variant == "key" ? NSColor(cgColor: rgb(0x3E2723))! : .white]))
        if let sym = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(cfg) {
            let s = sym.size
            sym.draw(in: NSRect(x: center.x - s.width / 2, y: center.y - s.height / 2, width: s.width, height: s.height))
        }
    }
    NSGraphicsContext.restoreGraphicsState()
}

func png(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    let c = ctx.cgContext
    c.interpolationQuality = .high
    c.scaleBy(x: CGFloat(px) / 1024, y: CGFloat(px) / 1024)
    draw(c)
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let iconset = fm.temporaryDirectory.appendingPathComponent("phimviet-\(variant)-\(getpid()).iconset")
try? fm.removeItem(at: iconset)
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! png(base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! png(base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try! p.run()
p.waitUntilExit()
// Bản PNG 1024 để xem trước / dùng trong README.
try? fm.copyItem(at: iconset.appendingPathComponent("icon_512x512@2x.png"),
                 to: output.deletingPathExtension().appendingPathExtension("png"))
try? fm.removeItem(at: iconset)
exit(p.terminationStatus)

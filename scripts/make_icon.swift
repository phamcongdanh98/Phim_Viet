// Vẽ biểu tượng template cho menu nhập liệu: ô bo góc đặc, chữ "V" khoét rỗng.
// Dùng: swiftc scripts/make_icon.swift -o build/make_icon && build/make_icon out.tiff
import AppKit

func rep(_ px: Int) -> NSBitmapImageRep {
    let r = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    r.size = NSSize(width: 16, height: 16)
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: r)!
    NSGraphicsContext.current = ctx
    NSColor.black.setFill()
    NSBezierPath(roundedRect: NSRect(x: 1, y: 1.5, width: 14, height: 13), xRadius: 3, yRadius: 3).fill()
    ctx.compositingOperation = .destinationOut
    let font = NSFont.systemFont(ofSize: 11.5, weight: .heavy)
    let s = NSAttributedString(string: "V", attributes: [.font: font, .foregroundColor: NSColor.black])
    let size = s.size()
    s.draw(at: NSPoint(x: (16 - size.width) / 2, y: (16 - size.height) / 2 + 0.5))
    NSGraphicsContext.restoreGraphicsState()
    return r
}

guard CommandLine.arguments.count == 2 else {
    fputs("dùng: make_icon <out.tiff>\n", stderr)
    exit(2)
}
let data = NSBitmapImageRep.tiffRepresentationOfImageReps(in: [rep(16), rep(32)], using: .lzw, factor: 0)!
try! data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))

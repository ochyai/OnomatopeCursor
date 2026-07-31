// アプリアイコン生成: 1024x1024 PNG を書き出す（build.sh から呼ばれる）
import AppKit

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let S: CGFloat = 1024

let img = NSImage(size: NSSize(width: S, height: S))
img.lockFocus()

// Big Sur スタイルの角丸スクエア + 漫画的な黄〜橙グラデーション
let margin: CGFloat = 100
let rect = NSRect(x: margin, y: margin, width: S - margin * 2, height: S - margin * 2)
let squircle = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)
let grad = NSGradient(colors: [
    NSColor(red: 1.00, green: 0.84, blue: 0.25, alpha: 1),
    NSColor(red: 1.00, green: 0.55, blue: 0.26, alpha: 1),
])!
grad.draw(in: squircle, angle: -90)

// 集中線（漫画らしさ）
NSColor(white: 1, alpha: 0.35).setStroke()
let center = NSPoint(x: S / 2, y: S / 2)
for k in 0..<24 {
    let a = CGFloat(k) / 24 * .pi * 2
    let line = NSBezierPath()
    line.lineWidth = 10
    line.lineCapStyle = .round
    line.move(to: NSPoint(x: center.x + cos(a) * 330, y: center.y + sin(a) * 330))
    line.line(to: NSPoint(x: center.x + cos(a) * 405, y: center.y + sin(a) * 405))
    line.stroke()
}

// 中央の「オ」（白・黒縁取り）
func drawChar(_ s: String, fontNames: [String], size: CGFloat, at p: NSPoint) {
    var font = NSFont.systemFont(ofSize: size, weight: .heavy)
    for n in fontNames { if let f = NSFont(name: n, size: size) { font = f; break } }
    let attr = NSAttributedString(string: s, attributes: [
        .font: font,
        .foregroundColor: NSColor.white,
        .strokeColor: NSColor.black,
        .strokeWidth: -5.0,
    ])
    let sz = attr.size()
    attr.draw(at: NSPoint(x: p.x - sz.width / 2, y: p.y - sz.height / 2))
}
drawChar("オ", fontNames: ["ToppanBunkyuMidashiGothicStdN-ExtraBold", "HiraginoSans-W9"],
         size: 560, at: NSPoint(x: S / 2, y: S / 2 + 10))

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("PNG生成に失敗\n", stderr)
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")

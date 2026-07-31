// θ→コミカル漫画描き文字レンダラ（ヘッドレス・Track Bの探索/検証用）
//   swift run onomatope-render <word> <v> <g> <e> <r> <out.png> [key=value ...]
// 画面・権限不要。1文字ずつバウンド/回転/スケールし、極太アウトライン・グラデ塗り・白ハローで
// BOOM!的なコミカル描き文字にする。StyleParamsを上書き可（審美探索が変種を作る）。
import AppKit
import OnomatopeCore

let a = CommandLine.arguments
guard a.count >= 7,
      let v = Double(a[2]), let g = Double(a[3]), let e = Double(a[4]), let r = Double(a[5]) else {
    print("usage: onomatope-render <word> <v> <g> <e> <r> <out.png> [sizeScale= tilt= hue= saturation= brightness= shadowDepth= speedLines= boilAmp= fontHeavy= outlineWidth= gradient= halo= charBounce= charRotJitter= charScaleJitter=]")
    exit(1)
}
let word = a[1]
let outPath = a[6]
// 学習済みh(θ)があれば読む（./i18n/stylemap.json）。--no-stylemap で無効化（探索の基準線用）
if !a.contains("--no-stylemap") {
    StyleMap.shared.load(from: URL(fileURLWithPath: "i18n/stylemap.json"))
}
var sp = StyleParams.from(theta: [v, g, e, r])
for arg in a.dropFirst(7) {
    let kv = arg.split(separator: "=", maxSplits: 1)
    guard kv.count == 2, let val = Double(kv[1]) else { continue }
    switch kv[0] {
    case "sizeScale": sp.sizeScale = val
    case "tilt": sp.tilt = val
    case "hue": sp.hue = val
    case "saturation": sp.saturation = val
    case "brightness": sp.brightness = val
    case "shadowDepth": sp.shadowDepth = val
    case "speedLines": sp.speedLines = Int(val)
    case "boilAmp": sp.boilAmp = val
    case "fontHeavy": sp.fontHeavy = val > 0.5
    case "outlineWidth": sp.outlineWidth = val
    case "gradient": sp.gradient = val
    case "halo": sp.halo = val
    case "charBounce": sp.charBounce = val
    case "charRotJitter": sp.charRotJitter = val
    case "charScaleJitter": sp.charScaleJitter = val
    case "pressure": sp.pressure = val
    case "taper": sp.taper = val
    case "roughness": sp.roughness = val
    default: break
    }
}

let W = 520, H = 220
let img = NSImage(size: NSSize(width: W, height: H))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext
NSColor(white: 0.12, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: W, height: H).fill()

// スピード線
if sp.speedLines > 0 {
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.7).cgColor)
    ctx.setLineWidth(3); ctx.setLineCap(.round)
    for i in 0..<sp.speedLines {
        let y = CGFloat(H / 2 - 30 + i * 14)
        ctx.move(to: CGPoint(x: 24, y: y)); ctx.addLine(to: CGPoint(x: 130, y: y + 6))
    }
    ctx.strokePath()
}

let fontName = sp.fontHeavy ? "ToppanBunkyuMidashiGothicStdN-ExtraBold" : "ToppanBunkyuMidashiMinchoStdN-ExtraBold"
let baseSize = 66 * sp.sizeScale
let font = NSFont(name: fontName, size: baseSize) ?? NSFont.systemFont(ofSize: baseSize, weight: .heavy)
let fill = NSColor(hue: CGFloat(sp.hue), saturation: CGFloat(sp.saturation), brightness: CGFloat(sp.brightness), alpha: 1)
let fillDark = NSColor(hue: CGFloat(sp.hue), saturation: min(1, CGFloat(sp.saturation) + 0.1),
                       brightness: max(0, CGFloat(sp.brightness) - CGFloat(sp.gradient) * 0.5), alpha: 1)
let outline = max(2, CGFloat(sp.outlineWidth) * 14)

// 各文字のグリフパスを取得
let chars = Array(word)
let ct = font as CTFont
var advances: [CGFloat] = []
var glyphPaths: [CGPath?] = []
for ch in chars {
    var u = Array(String(ch).utf16); var gl: CGGlyph = 0
    if u.count == 1, CTFontGetGlyphsForCharacters(ct, &u, &gl, 1), gl != 0 {
        advances.append(CGFloat(CTFontGetAdvancesForGlyphs(ct, .horizontal, &gl, nil, 1)))
        glyphPaths.append(CTFontCreatePathForGlyph(ct, gl, nil))
    } else { advances.append(baseSize); glyphPaths.append(nil) }
}
let tracking: CGFloat = baseSize * 0.06
let total = advances.reduce(0, +) + tracking * CGFloat(max(chars.count - 1, 0))
let fit = min(1.0, CGFloat(W) * 0.88 / max(total, 1))   // 横幅に収まるよう自動フィット

func hash(_ i: Int, _ salt: CGFloat) -> CGFloat { abs(sin(CGFloat(i) * 12.9898 + salt) * 43758.5453).truncatingRemainder(dividingBy: 1) }

ctx.saveGState()
ctx.translateBy(x: CGFloat(W) / 2, y: CGFloat(H) / 2)
ctx.rotate(by: CGFloat(sp.tilt))
ctx.scaleBy(x: fit, y: fit)
var x = -total / 2
for (i, path) in glyphPaths.enumerated() {
    let adv = advances[i]
    let bounce = (hash(i, 1) - 0.5) * CGFloat(sp.charBounce) * baseSize * 0.35
    let rot = (hash(i, 2) - 0.5) * CGFloat(sp.charRotJitter) * 0.5
    let scl = 1 + (hash(i, 3) - 0.5) * CGFloat(sp.charScaleJitter) * 0.6
    ctx.saveGState()
    ctx.translateBy(x: x + adv / 2, y: bounce)
    ctx.rotate(by: rot); ctx.scaleBy(x: scl, y: scl)
    if let raw = path {
        // 筆圧・テーパー（輪郭の法線方向変形）
        let path = BrushDeform.apply(to: raw, fontSize: baseSize,
                                     pressure: sp.pressure, taper: sp.taper,
                                     seed: CGFloat(i) * 3.3 + 1.2)
        // capHeight中心合わせ
        ctx.translateBy(x: -adv / 2, y: -CTFontGetCapHeight(ct) / 2)
        // 影
        if sp.shadowDepth > 0.05 {
            ctx.saveGState(); ctx.translateBy(x: 3 * CGFloat(sp.shadowDepth), y: -3 * CGFloat(sp.shadowDepth))
            ctx.addPath(path); ctx.setFillColor(NSColor.black.withAlphaComponent(CGFloat(sp.shadowDepth)).cgColor); ctx.fillPath()
            ctx.restoreGState()
        }
        // 白ハロー
        if sp.halo > 0.05 {
            ctx.addPath(path); ctx.setLineWidth(outline + CGFloat(sp.halo) * 10); ctx.setLineJoin(.round)
            ctx.setStrokeColor(NSColor.white.cgColor); ctx.strokePath()
        }
        // 極太黒アウトライン
        ctx.addPath(path); ctx.setLineWidth(outline); ctx.setLineJoin(.round)
        ctx.setStrokeColor(NSColor.black.cgColor); ctx.strokePath()
        // グラデ塗り（クリップして縦グラデ）
        ctx.saveGState()
        ctx.addPath(path); ctx.clip()
        let bb = path.boundingBox
        let cs = CGColorSpaceCreateDeviceRGB()
        if let grad = CGGradient(colorsSpace: cs, colors: [fill.cgColor, fillDark.cgColor] as CFArray, locations: [0, 1]) {
            ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: bb.maxY), end: CGPoint(x: 0, y: bb.minY), options: [])
        }
        // かすれ: グリフ内の削り筋（アプリでは透明抜き。ここでは背景色で塗り=同じ見え）
        if sp.roughness > 0.03 {
            ctx.setStrokeColor(NSColor(white: 0.12, alpha: 1).cgColor)
            ctx.setLineCap(.round)
            for (k, ln) in BrushDeform.scratchLines(bbox: bb, fontSize: baseSize,
                                                    roughness: sp.roughness, seed: CGFloat(i) * 1.7).enumerated() {
                ctx.setLineWidth(ln.width)
                ctx.setLineDash(phase: 0,
                                lengths: BrushDeform.scratchDash(fontSize: baseSize, seed: CGFloat(i) * 1.7, index: k))
                ctx.move(to: ln.from); ctx.addLine(to: ln.to)
                ctx.strokePath()
            }
            ctx.setLineDash(phase: 0, lengths: [])
        }
        ctx.restoreGState()
    }
    ctx.restoreGState()
    x += adv + tracking
}
ctx.restoreGState()
img.unlockFocus()

guard let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)  outline=\(String(format: "%.2f", sp.outlineWidth)) grad=\(String(format: "%.2f", sp.gradient)) halo=\(String(format: "%.2f", sp.halo)) bounce=\(String(format: "%.2f", sp.charBounce))")

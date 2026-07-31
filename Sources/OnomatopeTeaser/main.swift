// ティザー動画用 透過フレーム連番レンダラ
//   swift run onomatope-teaser <outdir> [--fps 30] [--scale 1.0]
// 合成カーソル（矢印+残像）と描き文字アニメを透過PNG連番で出力する。
// 背景合成・カット編集は tools/teaser_compose.sh（ffmpeg）が行う。
// シーンの切れ目はstdoutにフレーム番号で出す（編集点）。
import AppKit
import OnomatopeCore

// ── 引数 ──
let argv = CommandLine.arguments
guard argv.count >= 2 else { print("usage: onomatope-teaser <outdir> [--fps 30]"); exit(1) }
let outDir = URL(fileURLWithPath: argv[1], isDirectory: true)
var FPS = 30.0
if let i = argv.firstIndex(of: "--fps"), i + 1 < argv.count { FPS = Double(argv[i + 1]) ?? 30 }
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let W = 1600.0, H = 900.0

// ── シーン定義 ──
struct WordEvent { let t: Double; let word: String; let theta: [Double]; let hold: Double
    var at: CGPoint? = nil }   // at=アンカー固定（省略時はカーソル/キャレット）
struct Scene {
    let name: String
    let dur: Double
    let lang: String                        // ja/en/zh/ko/fr（フォント選択）
    let path: (Double) -> CGPoint          // u∈[0,1] → カーソル位置
    let words: [WordEvent]                  // tはシーン内秒
    let showCursor: Bool                    // 矢印カーソルを描くか（打鍵シーンは非表示）
    let speedLines: Bool                    // 突進シーンの速度線
    /// カスタム描画（打鍵シーン等）。tを受けて描画し、語のアンカー（キャレット位置）を返す
    let extra: ((CGContext, Double) -> CGPoint)?

    init(name: String, dur: Double, lang: String = "ja",
         path: @escaping (Double) -> CGPoint, words: [WordEvent],
         showCursor: Bool = true, speedLines: Bool = false,
         extra: ((CGContext, Double) -> CGPoint)? = nil) {
        self.name = name; self.dur = dur; self.lang = lang; self.path = path
        self.words = words; self.showCursor = showCursor; self.speedLines = speedLines
        self.extra = extra
    }
}

func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }
let cx = W * 0.5, cy = H * 0.52

// 高速モンタージュ: 各シーン約1.5秒・語は0.2秒で登場してカットまで居座る。
// 前半=日本語、後半=多国籍（各言語の正式語彙 i18n/vocab-*.json 準拠）
func ev(_ word: String, _ theta: [Double], t: Double = 0.2, hold: Double = 9) -> [WordEvent] {
    [WordEvent(t: t, word: word, theta: theta, hold: hold)]
}
func dashPath(_ u: Double) -> CGPoint {
    let e = 1 - pow(1 - min(u * 1.25, 1), 3)
    return pt(cx - 430 + 860 * e, cy - 30 + sin(u * 3) * 8)
}
func circlePath(_ u: Double) -> CGPoint {
    pt(cx + cos(u * .pi * 2 * 1.7) * 180, cy + sin(u * .pi * 2 * 1.7) * 140)
}
// 衝撃演出: 語の登場瞬間に白フラッシュ＋画面シェイク（漫画のヒットストップ）
let HIT_BIG: Set<String> = ["ピタッ!!", "SMACK!!", "따앙!!", "ッターン！", "バチンッ"]
let HIT_SMALL: Set<String> = ["カチッ", "CLIC !"]
// ── 打鍵シーン: 三言語のタグラインが3行並列で同時にタイプされていく ──
let TYPE_START = 0.25, TYPE_DUR = 12.0 / 9.0          // 全行がこの時間で打ち終わる
let typeDone = TYPE_START + TYPE_DUR                   // ≈1.58s（音・シーン尺の基準）
let TAGLINE = "うごきが、ことばになる。"                    // 上段（カタカタのキック位相にも使用）
let CPS = Double(TAGLINE.count) / TYPE_DUR
struct TypeLine {
    let text: String; let font: NSFont; let n: Int
    init(_ text: String, _ fontName: String, _ size: Double) {
        self.text = text
        self.font = NSFont(name: fontName, size: size) ?? NSFont.systemFont(ofSize: size, weight: .semibold)
        self.n = text.count
    }
}
let typeLines: [TypeLine] = [
    TypeLine(TAGLINE, "HiraginoSans-W6", 40),
    TypeLine("Motion becomes words.", "HelveticaNeue-Bold", 38),
    TypeLine("动作，变成语言。", "PingFangSC-Semibold", 38),
]
let cardW = 900.0, rowH = 96.0, rowGap = 16.0

func typingExtra(_ ctx: CGContext, _ t: Double) -> CGPoint {
    var topCaret = CGPoint(x: cx, y: cy)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    for (i, line) in typeLines.enumerated() {
        let rowTop = cy + 66 - Double(i) * (rowH + rowGap)   // 上から日/英/中
        let card = CGRect(x: cx - cardW / 2, y: rowTop - rowH, width: cardW, height: rowH)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -5), blur: 18,
                      color: NSColor.black.withAlphaComponent(0.32).cgColor)
        ctx.addPath(CGPath(roundedRect: card, cornerWidth: 16, cornerHeight: 16, transform: nil))
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fillPath()
        ctx.restoreGState()
        // この行のcps（全行同時に打ち終わる）
        let cps = Double(line.n) / TYPE_DUR
        let k = max(0, min(line.n, Int((t - TYPE_START) * cps)))
        let typed = String(line.text.prefix(k))
        let attr = NSAttributedString(string: typed, attributes: [
            .font: line.font, .foregroundColor: NSColor(white: 0.15, alpha: 1)])
        let full = NSAttributedString(string: line.text, attributes: [.font: line.font])
        let startX = card.midX - full.size().width / 2
        attr.draw(at: NSPoint(x: startX, y: card.midY - attr.size().height / 2))
        // キャレット（行ごと・点滅）
        let caretX = startX + attr.size().width + 2
        if t < typeDone || Int(t * 3 + Double(i)) % 2 == 0 {
            ctx.setFillColor(NSColor(calibratedRed: 0.25, green: 0.5, blue: 1, alpha: 1).cgColor)
            ctx.fill(CGRect(x: caretX, y: card.midY - 22, width: 3.5, height: 44))
        }
        if i == 0 { topCaret = CGPoint(x: caretX, y: card.midY - 4) }
    }
    NSGraphicsContext.restoreGraphicsState()
    return topCaret
}

// キレ優先: ヒット系は当てたら即切る。締め=打鍵→ッターン！→タイトルカード
let scenes: [Scene] = [
    // ── 日本語パート ──
    Scene(name: "byuun", dur: 0.95, path: dashPath,
          words: ev("ビューン", [0.5, 0.75, 0.85, 0.0], t: 0.12), speedLines: true),
    Scene(name: "pita", dur: 0.9,
          path: { u in u < 0.3 ? pt(cx - 260 + 870 * u, cy) : pt(cx, cy) },
          words: ev("ピタッ!!", [0.55, 0.98, 0.0, 0.0], t: 0.2)),
    Scene(name: "guru", dur: 1.1, path: circlePath,
          words: ev("グルグル", [0.45, 0.35, 0.1, 0.95], t: 0.12)),
    Scene(name: "puru", dur: 0.9,
          path: { u in pt(cx + sin(u * 210) * 5, cy + cos(u * 180) * 4) },
          words: ev("プルプル", [0.2, 0.25, 0.0, 0.9], t: 0.12)),
    Scene(name: "kachi", dur: 0.7, path: { _ in pt(cx, cy) },
          words: ev("カチッ", [0.45, 0.6, 0.0, 0.0], t: 0.1)),
    // ── 多国籍パート ──
    Scene(name: "zoom_en", dur: 0.9, lang: "en", path: dashPath,
          words: ev("ZOOOM!", [0.5, 0.75, 0.85, 0.0], t: 0.12), speedLines: true),
    Scene(name: "smack_en", dur: 0.8, lang: "en", path: { _ in pt(cx, cy) },
          words: ev("SMACK!!", [0.9, 0.95, 0.0, 0.0], t: 0.1)),
    Scene(name: "sou_zh", dur: 0.9, lang: "zh", path: dashPath,
          words: ev("嗖——!", [0.5, 0.75, 0.85, 0.0], t: 0.12), speedLines: true),
    Scene(name: "pili_zh", dur: 1.0, lang: "zh", path: { _ in pt(cx, cy + 10) },
          words: ev("噼里啪啦", [0.6, 0.5, 0.0, 1.0], t: 0.1)),
    Scene(name: "bingle_ko", dur: 1.1, lang: "ko", path: circlePath,
          words: ev("빙글빙글", [0.45, 0.35, 0.1, 0.95], t: 0.12)),
    Scene(name: "ttang_ko", dur: 0.8, lang: "ko", path: { _ in pt(cx, cy) },
          words: ev("따앙!!", [0.75, 0.95, 0.3, 0.0], t: 0.1)),
    Scene(name: "clic_fr", dur: 0.7, lang: "fr", path: { _ in pt(cx, cy) },
          words: ev("CLIC !", [0.45, 0.6, 0.0, 0.0], t: 0.1)),
    Scene(name: "zioum_fr", dur: 0.9, lang: "fr", path: dashPath,
          words: ev("ZIOUUUM !", [0.5, 0.75, 0.85, 0.0], t: 0.12), speedLines: true),
    // ── 締め: タイプ→キャレットの上でカタカタカタ→Enter→ッターン！ ──
    Scene(name: "typing", dur: typeDone + 1.35,
          path: { _ in pt(cx, cy) },
          words: [WordEvent(t: TYPE_START, word: "カタカタカタ", theta: [0.6, 0.4, 0.0, 1.0],
                            hold: typeDone - TYPE_START + 0.1),
                  WordEvent(t: typeDone + 0.25, word: "ッターン！", theta: [0.75, 0.95, 0.3, 0.0],
                            hold: 9, at: CGPoint(x: cx, y: cy + 70))],
          showCursor: false, extra: typingExtra),
    // ── タイトルカード ──
    Scene(name: "title", dur: 1.7, path: { _ in pt(cx, cy) },
          words: [], showCursor: false, extra: titleExtra),
]

// タイトルカード: 暗幕フェード→アイコン＋アプリ名＋タグライン
let appIcon = NSImage(contentsOfFile: "packaging/AppIcon.icns")
func titleExtra(_ ctx: CGContext, _ t: Double) -> CGPoint {
    let a = min(1.0, t / 0.22)
    ctx.setFillColor(NSColor(calibratedWhite: 0.08, alpha: 0.96 * a).cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    let popT = max(0, t - 0.12)
    let pop = max(0.01, 1.0 - exp(-8.0 * popT) * cos(11.0 * popT))
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    if let icon = appIcon {
        let sz = 168.0 * pop
        icon.draw(in: NSRect(x: cx - sz / 2, y: cy + 60 - sz / 2, width: sz, height: sz))
    }
    let name = NSAttributedString(string: "オノマトペカーソル", attributes: [
        .font: NSFont(name: "ToppanBunkyuMidashiGothicStdN-ExtraBold", size: 58)
            ?? NSFont.systemFont(ofSize: 58, weight: .heavy),
        .foregroundColor: NSColor.white.withAlphaComponent(a)])
    name.draw(at: NSPoint(x: cx - name.size().width / 2, y: cy - 80))
    let subLines = ["うごきが、ことばになる。", "Motion becomes words.", "动作，变成语言。"]
    for (i, line) in subLines.enumerated() {
        let sub = NSAttributedString(string: line, attributes: [
            .font: NSFont(name: i == 2 ? "PingFangSC-Regular" : "HiraginoSans-W4", size: 23)
                ?? NSFont.systemFont(ofSize: 23),
            .foregroundColor: NSColor(calibratedWhite: 0.82, alpha: a)])
        sub.draw(at: NSPoint(x: cx - sub.size().width / 2, y: cy - 140 - Double(i) * 38))
    }
    let credit = NSAttributedString(string: "OnomatopeCursor for macOS", attributes: [
        .font: NSFont.systemFont(ofSize: 19, weight: .medium),
        .foregroundColor: NSColor(calibratedWhite: 0.55, alpha: a)])
    credit.draw(at: NSPoint(x: cx - credit.size().width / 2, y: cy - 262))
    NSGraphicsContext.restoreGraphicsState()
    return CGPoint(x: cx, y: cy)
}

// ── 描き文字レンダリング（onomatope-renderの動的版） ──
let langNamesGothic = "ToppanBunkyuMidashiGothicStdN-ExtraBold"
let langNamesMincho = "ToppanBunkyuMidashiMinchoStdN-ExtraBold"

func hash01(_ i: Int, _ salt: Double) -> Double {
    abs(sin(Double(i) * 12.9898 + salt) * 43758.5453).truncatingRemainder(dividingBy: 1)
}

/// 言語→フォント（アプリのLANG_FONTSと同じ系統）
func pickFontName(lang: String, heavy: Bool) -> String {
    switch lang {
    case "en", "fr": return heavy ? "ChalkboardSE-Bold" : "ChalkboardSE-Regular"
    case "zh": return heavy ? "PingFangSC-Semibold" : "PingFangSC-Medium"
    case "ko": return heavy ? "AppleSDGothicNeo-Heavy" : "AppleSDGothicNeo-Bold"
    default:   return heavy ? langNamesGothic : langNamesMincho
    }
}

/// 1語を描く。age=表示からの秒数（ポップイン・ボイル用）、pos=カーソル位置（上に出す）
func drawWord(_ ctx: CGContext, word: String, theta: [Double], age: Double, pos: CGPoint,
              lang: String = "ja") {
    let sp = StyleParams.from(theta: theta)
    let fontName = pickFontName(lang: lang, heavy: sp.fontHeavy)
    let baseSize = 84 * sp.sizeScale   // 高速カットでも読めるサイズ
    guard let font = NSFont(name: fontName, size: baseSize) ?? NSFont.systemFont(ofSize: baseSize, weight: .heavy) as NSFont? else { return }
    let ct = font as CTFont
    let fill = NSColor(hue: sp.hue, saturation: sp.saturation, brightness: sp.brightness, alpha: 1)
    let fillDark = NSColor(hue: sp.hue, saturation: min(1, sp.saturation + 0.1),
                           brightness: max(0, sp.brightness - sp.gradient * 0.5), alpha: 1)
    let outline = max(2, sp.outlineWidth * 14)

    // ポップイン: オーバーシュートして登場
    let popU = max(age, 0.0001)
    let pop = max(0.01, 1.0 - exp(-8.0 * popU) * cos(11.0 * popU))
    let boil = Int(age * 8)   // 8fpsでボイル位相

    let chars = Array(word)
    var advances: [CGFloat] = []
    var glyphs: [CGPath?] = []
    for ch in chars {
        var u = Array(String(ch).utf16); var gl: CGGlyph = 0
        if u.count == 1, CTFontGetGlyphsForCharacters(ct, &u, &gl, 1), gl != 0 {
            advances.append(CGFloat(CTFontGetAdvancesForGlyphs(ct, .horizontal, &gl, nil, 1)))
            glyphs.append(CTFontCreatePathForGlyph(ct, gl, nil))
        } else { advances.append(baseSize); glyphs.append(nil) }
    }
    let tracking = baseSize * 0.06
    let total = advances.reduce(0, +) + tracking * CGFloat(max(chars.count - 1, 0))

    ctx.saveGState()
    ctx.translateBy(x: pos.x, y: pos.y + 95)          // カーソルの上に
    ctx.rotate(by: sp.tilt)
    ctx.scaleBy(x: pop, y: pop)
    var x = -total / 2
    for (i, raw) in glyphs.enumerated() {
        let adv = advances[i]
        let bounce = (hash01(i, 1) - 0.5) * sp.charBounce * baseSize * 0.3
            + sin(age * 9 + Double(i) * 1.3) * sp.charBounce * baseSize * 0.06   // 生きた上下
        let rot = (hash01(i, 2) - 0.5) * sp.charRotJitter * 0.4
        let scl = 1 + (hash01(i, 3) - 0.5) * sp.charScaleJitter * 0.5
        ctx.saveGState()
        ctx.translateBy(x: x + adv / 2, y: bounce)
        ctx.rotate(by: rot); ctx.scaleBy(x: scl, y: scl)
        if let raw {
            let path = BrushDeform.apply(to: raw, fontSize: baseSize,
                                         pressure: sp.pressure, taper: sp.taper,
                                         seed: CGFloat(i) * 3.3 + CGFloat(boil % 3) * 5.1)
            ctx.translateBy(x: -adv / 2, y: -CTFontGetCapHeight(ct) / 2)
            // 影
            ctx.saveGState(); ctx.translateBy(x: 3 * sp.shadowDepth, y: -3 * sp.shadowDepth)
            ctx.addPath(path); ctx.setFillColor(NSColor.black.withAlphaComponent(0.45 * sp.shadowDepth).cgColor); ctx.fillPath()
            ctx.restoreGState()
            // 白ハロー
            if sp.halo > 0.05 {
                ctx.addPath(path); ctx.setLineWidth(outline + sp.halo * 10); ctx.setLineJoin(.round)
                ctx.setStrokeColor(NSColor.white.cgColor); ctx.strokePath()
            }
            // 黒フチ
            ctx.addPath(path); ctx.setLineWidth(outline); ctx.setLineJoin(.round)
            ctx.setStrokeColor(NSColor.black.cgColor); ctx.strokePath()
            // 縦グラデ
            ctx.saveGState(); ctx.addPath(path); ctx.clip()
            let bb = path.boundingBox
            let cs = CGColorSpaceCreateDeviceRGB()
            if let grad = CGGradient(colorsSpace: cs, colors: [fill.cgColor, fillDark.cgColor] as CFArray, locations: [0, 1]) {
                ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: bb.maxY), end: CGPoint(x: 0, y: bb.minY), options: [])
            }
            // かすれ
            if sp.roughness > 0.03 {
                ctx.setBlendMode(.destinationOut)
                ctx.setLineCap(.round)
                for (k, ln) in BrushDeform.scratchLines(bbox: bb, fontSize: baseSize,
                                                        roughness: sp.roughness, seed: CGFloat(i) * 1.7 + CGFloat(boil % 3)).enumerated() {
                    ctx.setLineWidth(ln.width)
                    ctx.setLineDash(phase: 0, lengths: BrushDeform.scratchDash(fontSize: baseSize, seed: CGFloat(i) * 1.7, index: k))
                    ctx.move(to: ln.from); ctx.addLine(to: ln.to); ctx.strokePath()
                }
                ctx.setLineDash(phase: 0, lengths: [])
                ctx.setBlendMode(.normal)
            }
            ctx.restoreGState()
        }
        ctx.restoreGState()
        x += adv + tracking
    }
    ctx.restoreGState()
}

// ── カーソル描画（macOS風矢印+残像） ──
func cursorPath() -> CGPath {
    // 標準ポインタ風の輪郭（上向き基準、原点=先端）
    let p = CGMutablePath()
    let pts: [(Double, Double)] = [(0, 0), (0, -17.2), (4.2, -13.6), (7.2, -19.8),
                                   (10.2, -18.3), (7.3, -12.2), (12.6, -12.4)]
    p.move(to: pt(pts[0].0, pts[0].1))
    for q in pts.dropFirst() { p.addLine(to: pt(q.0, q.1)) }
    p.closeSubpath()
    var tf = CGAffineTransform(scaleX: 1.7, y: 1.7)
    return p.copy(using: &tf) ?? p
}
let cursorShape = cursorPath()

func drawCursor(_ ctx: CGContext, at p: CGPoint, trail: [CGPoint]) {
    // 残像（速度感）
    for (i, tp) in trail.enumerated() {
        let a = Double(i + 1) / Double(trail.count + 1) * 0.25
        ctx.setFillColor(NSColor.white.withAlphaComponent(a).cgColor)
        ctx.fillEllipse(in: CGRect(x: tp.x - 4, y: tp.y - 4, width: 8, height: 8))
    }
    ctx.saveGState()
    ctx.translateBy(x: p.x, y: p.y)
    ctx.setShadow(offset: CGSize(width: 1.5, height: -1.5), blur: 3,
                  color: NSColor.black.withAlphaComponent(0.5).cgColor)
    ctx.addPath(cursorShape)
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillPath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    ctx.addPath(cursorShape)
    ctx.setLineWidth(1.6)
    ctx.setStrokeColor(NSColor.black.cgColor)
    ctx.strokePath()
    ctx.restoreGState()
}

// ── フレーム生成 ──
let cs = CGColorSpaceCreateDeviceRGB()
var frameIdx = 0
var sceneStarts: [(String, Int)] = []
var trailBuf: [CGPoint] = []

for scene in scenes {
    sceneStarts.append((scene.name, frameIdx))
    let n = Int(scene.dur * FPS)
    for f in 0..<n {
        let t = Double(f) / FPS
        let u = t / scene.dur
        let cpos = scene.path(u)
        trailBuf.append(cpos)
        if trailBuf.count > 7 { trailBuf.removeFirst() }

        guard let ctx = CGContext(data: nil, width: Int(W), height: Int(H),
                                  bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { continue }
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)

        // 表示中の語（後の語が勝つ=アプリと同じ）
        var active: WordEvent?
        for ev in scene.words where t >= ev.t && t < ev.t + ev.hold { active = ev }

        // ヒットの瞬間: 画面シェイク（減衰）
        var shakeX = 0.0, shakeY = 0.0, flashA = 0.0
        if let ev = active {
            let age = t - ev.t
            let amp = HIT_BIG.contains(ev.word) ? 7.5 : (HIT_SMALL.contains(ev.word) ? 2.5 : 0)
            if amp > 0, age < 0.4 {
                shakeX = sin(age * 90) * amp * exp(-age * 9)
                shakeY = cos(age * 74) * amp * 0.7 * exp(-age * 9)
                if age < 0.07 { flashA = (HIT_BIG.contains(ev.word) ? 0.42 : 0.18) * (1 - age / 0.07) }
            }
        }
        ctx.saveGState()
        ctx.translateBy(x: shakeX, y: shakeY)

        // カスタム描画（打鍵カード等）。返り値=キャレット位置が語のアンカーになる
        var anchor = cpos
        if let extra = scene.extra { anchor = extra(ctx, t) }

        // 打鍵同期: カタカタカタは1打ごとにピクッと跳ねる
        if scene.name == "typing", let ev = active, ev.word == "カタカタカタ" {
            let phase = ((t - TYPE_START) * CPS).truncatingRemainder(dividingBy: 1)
            anchor.y += 7 * exp(-phase * 5)
        }

        // 速度線（突進シーン: カーソルの後方に流れる）
        if scene.speedLines, t > 0.05 {
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.85).cgColor)
            ctx.setLineCap(.round)
            for k in 0..<3 {
                let ly = cpos.y - 18 + Double(k) * 18 + sin(t * 9 + Double(k)) * 3
                let len = 55.0 + Double(k % 2) * 28
                ctx.setLineWidth(3.5)
                ctx.move(to: pt(cpos.x - 26, ly))
                ctx.addLine(to: pt(cpos.x - 26 - len, ly))
                ctx.strokePath()
            }
        }

        if let ev = active {
            drawWord(ctx, word: ev.word, theta: ev.theta, age: t - ev.t,
                     pos: ev.at ?? anchor, lang: scene.lang)
        }
        if scene.showCursor {
            drawCursor(ctx, at: cpos, trail: Array(trailBuf.dropLast()))
        }
        ctx.restoreGState()

        // 白フラッシュ（シェイクの影響を受けない全画面）
        if flashA > 0 {
            ctx.setFillColor(NSColor.white.withAlphaComponent(flashA).cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
        }

        if let img = ctx.makeImage() {
            let rep = NSBitmapImageRep(cgImage: img)
            if let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: outDir.appendingPathComponent(String(format: "f_%05d.png", frameIdx)))
            }
        }
        frameIdx += 1
    }
    trailBuf.removeAll()
}

print("frames: \(frameIdx) @\(Int(FPS))fps  (\(String(format: "%.1f", Double(frameIdx) / FPS))s)")
for (name, start) in sceneStarts { print("scene \(name): frame \(start)") }

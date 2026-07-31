// OnomatopeCursor — マウスの動きを漫画文字の擬態語として可視化するオーバーレイ
// 運動語15 + 文脈語3（背景モード・Accessibility権限が必要）。
// 特徴量トラッカー・分類器・研究ログは OnomatopeCore（テスト対象）に分離。
// 描画: グリフをCGPath化し輪郭を手描き風に揺らした3バリアントを8fpsで切替（ボイルアニメ）
import Carbon.HIToolbox
import Cocoa
import ApplicationServices
import IOKit.hid
import OnomatopeCore

// バンドルのInfo.plist（build.shがVERSIONから埋める）を正とする。swift run時は"dev"
let APP_VERSION = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"

// MARK: - スタイル定義

enum Anim { case kyoro, oro, soro, guru, kuru, byuun, pita, puru, suu, sui, bun, pyon, dadada, uro, jiri, fumu, jiro, doki, kacha, tturn, suru, gaa, gaba, kyu, shuru, sha, guri, pochi, kachi2, migi, gui, zuru, kata, gata, poi, iki, jiwa, sowa, moji, biku, uto, boo, muzu, chigau }

struct WordStyle {
    let text: String
    let fontNames: [String]
    let size: CGFloat
    let color: NSColor
    let anim: Anim
    // コミカル描き文字（comicFX時）。既定は控えめ。生成語はθ→StyleParamsで上書きされる
    var outline: CGFloat = 0.5   // 極太黒フチの強さ 0..1
    var gradient: CGFloat = 0.55 // 上明→下暗の縦グラデ 0..1
    var halo: CGFloat = 0.6      // 白フチのハロー 0..1
    // 筆のベクター変形（BrushDeform）
    var pressure: CGFloat = 0.45 // 筆圧: 輪郭の低周波太細 0..1
    var taper: CGFloat = 0.35    // テーパー: 画の入り抜きの痩せ 0..1
    var roughness: CGFloat = 0.2 // かすれ: 削り筋 0..1
}

// 凸版文久見出しゴシック/ミンチョが未インストールの環境ではヒラギノ極太にフォールバック
let GOTHIC = ["ToppanBunkyuMidashiGothicStdN-ExtraBold", "HiraginoSans-W9", "HiraginoSans-W8"]
let MINCHO = ["ToppanBunkyuMidashiMinchoStdN-ExtraBold", "HiraginoSans-W9", "HiraginoSans-W8"]

// 言語別の描き文字フォント（動的系/静的系）。色・アニメはcanonicalキー側に紐付くため言語非依存
let LANG_FONTS: [String: (gothic: [String], mincho: [String])] = [
    "ja": (GOTHIC, MINCHO),
    "en": (["ChalkboardSE-Bold", "ArialRoundedMTBold", "Futura-Bold"], ["ChalkboardSE-Regular", "Georgia-Bold"]),
    "fr": (["ChalkboardSE-Bold", "ArialRoundedMTBold", "Futura-Bold"], ["ChalkboardSE-Regular", "Georgia-Bold"]),
    "zh": (["PingFangSC-Semibold", "PingFangSC-Medium"], ["STSongti-SC-Bold", "PingFangSC-Regular"]),
    "ko": (["AppleSDGothicNeo-Heavy", "AppleSDGothicNeo-Bold"], ["AppleSDGothicNeo-Medium"]),
]

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
    NSColor(red: r, green: g, blue: b, alpha: 1)
}

let STYLES: [String: WordStyle] = [
    // 運動語
    "キョロキョロ": WordStyle(text: "キョロキョロ", fontNames: GOTHIC, size: 32, color: .white, anim: .kyoro),
    "オロオロ":    WordStyle(text: "オロオロ", fontNames: GOTHIC, size: 32, color: rgb(0.78, 0.90, 1.0), anim: .oro),
    "ソロソロ":    WordStyle(text: "ソロソロ", fontNames: MINCHO, size: 28, color: rgb(0.85, 0.96, 0.82), anim: .soro),
    "ジリジリ":    WordStyle(text: "ジリジリ", fontNames: MINCHO, size: 27, color: rgb(1.0, 0.70, 0.28), anim: .jiri),
    "グルグル":    WordStyle(text: "グルグル", fontNames: GOTHIC, size: 32, color: rgb(1.0, 0.90, 0.35), anim: .guru),
    "クルクル":    WordStyle(text: "クルクル", fontNames: GOTHIC, size: 28, color: rgb(0.50, 0.89, 0.83), anim: .kuru),
    "ビューン":    WordStyle(text: "ビューン", fontNames: GOTHIC, size: 38, color: rgb(1.0, 0.82, 0.20), anim: .byuun),
    "ピタッ!!":    WordStyle(text: "ピタッ!!", fontNames: GOTHIC, size: 38, color: rgb(1.0, 0.36, 0.36), anim: .pita),
    "プルプル":    WordStyle(text: "プルプル", fontNames: GOTHIC, size: 27, color: rgb(0.90, 0.80, 1.0), anim: .puru),
    "スーッ":      WordStyle(text: "スーッ", fontNames: MINCHO, size: 30, color: rgb(0.74, 0.92, 1.0), anim: .suu),
    "スイスイ":    WordStyle(text: "スイスイ", fontNames: MINCHO, size: 29, color: rgb(0.44, 0.83, 1.0), anim: .sui),
    "ブンブン":    WordStyle(text: "ブンブン", fontNames: GOTHIC, size: 34, color: rgb(1.0, 0.55, 0.26), anim: .bun),
    "ピョンピョン": WordStyle(text: "ピョンピョン", fontNames: GOTHIC, size: 30, color: rgb(0.61, 0.90, 0.39), anim: .pyon),
    "ダダダッ":    WordStyle(text: "ダダダッ", fontNames: GOTHIC, size: 34, color: rgb(1.0, 0.42, 0.42), anim: .dadada),
    "ウロウロ":    WordStyle(text: "ウロウロ", fontNames: GOTHIC, size: 29, color: rgb(0.93, 0.87, 0.71), anim: .uro),
    // 文脈語（背景モード）
    "フムフム":    WordStyle(text: "フムフム", fontNames: MINCHO, size: 28, color: rgb(0.88, 0.93, 1.0), anim: .fumu),
    "ジロジロ":    WordStyle(text: "ジロジロ", fontNames: GOTHIC, size: 29, color: rgb(0.80, 0.85, 0.95), anim: .jiro),
    "ドキドキ":    WordStyle(text: "ドキドキ", fontNames: GOTHIC, size: 30, color: rgb(1.0, 0.62, 0.77), anim: .doki),
    // キーボード語（キーボードモード）
    "カチャカチャ": WordStyle(text: "カチャカチャ", fontNames: GOTHIC, size: 26, color: rgb(0.91, 0.91, 0.96), anim: .kacha),
    "ッターン！":   WordStyle(text: "ッターン！", fontNames: GOTHIC, size: 42, color: rgb(1.0, 0.55, 0.26), anim: .tturn),
    // トラックパッド語（トラックパッドモード）
    "スルスル":    WordStyle(text: "スルスル", fontNames: MINCHO, size: 28, color: rgb(0.72, 0.94, 0.90), anim: .suru),
    "ガーッ":      WordStyle(text: "ガーッ", fontNames: GOTHIC, size: 34, color: rgb(0.66, 0.94, 1.0), anim: .gaa),
    "シュルシュル": WordStyle(text: "シュルシュル", fontNames: MINCHO, size: 27, color: rgb(0.80, 0.92, 0.80), anim: .shuru),
    "シャッ":      WordStyle(text: "シャッ", fontNames: GOTHIC, size: 32, color: rgb(0.92, 0.95, 1.0), anim: .sha),
    "ガバーッ":    WordStyle(text: "ガバーッ", fontNames: GOTHIC, size: 38, color: rgb(1.0, 0.70, 0.28), anim: .gaba),
    "キュッ":      WordStyle(text: "キュッ", fontNames: GOTHIC, size: 28, color: rgb(1.0, 0.62, 0.77), anim: .kyu),
    "グリグリ":    WordStyle(text: "グリグリ", fontNames: GOTHIC, size: 30, color: rgb(0.85, 0.72, 1.0), anim: .guri),
    // クリック語（クリックモード）
    "ポチッ":      WordStyle(text: "ポチッ", fontNames: GOTHIC, size: 28, color: rgb(1.0, 0.91, 0.94), anim: .pochi),
    "カチカチッ":  WordStyle(text: "カチカチッ", fontNames: GOTHIC, size: 30, color: rgb(0.78, 0.90, 1.0), anim: .kachi2),
    "ミギクリッ！": WordStyle(text: "ミギクリッ！", fontNames: GOTHIC, size: 30, color: rgb(0.60, 0.92, 0.68), anim: .migi),
    // ドラッグ語・段差語（物理モード）
    "グイグイ":    WordStyle(text: "グイグイ", fontNames: GOTHIC, size: 32, color: rgb(1.0, 0.76, 0.54), anim: .gui),
    "ズルズル":    WordStyle(text: "ズルズル", fontNames: MINCHO, size: 28, color: rgb(0.79, 0.76, 0.72), anim: .zuru),
    "カタッ":      WordStyle(text: "カタッ", fontNames: GOTHIC, size: 26, color: rgb(0.91, 0.89, 0.86), anim: .kata),
    "ガタガタッ":  WordStyle(text: "ガタガタッ", fontNames: GOTHIC, size: 32, color: rgb(1.0, 0.85, 0.54), anim: .gata),
    "ポィ！":      WordStyle(text: "ポィ！", fontNames: GOTHIC, size: 32, color: rgb(0.80, 0.95, 0.60), anim: .poi),
    // アイドル語（静止時の生物的な気配）
    "すぅすぅ":    WordStyle(text: "すぅすぅ", fontNames: MINCHO, size: 22, color: rgb(0.80, 0.86, 0.95), anim: .iki),
    "じわじわ":    WordStyle(text: "じわじわ", fontNames: MINCHO, size: 22, color: rgb(0.83, 0.90, 0.80), anim: .jiwa),
    "そわそわ":    WordStyle(text: "そわそわ", fontNames: MINCHO, size: 22, color: rgb(0.93, 0.88, 0.78), anim: .sowa),
    "もじもじ":    WordStyle(text: "もじもじ", fontNames: MINCHO, size: 22, color: rgb(0.92, 0.83, 0.90), anim: .moji),
    "ビクビクッ":  WordStyle(text: "ビクビクッ", fontNames: GOTHIC, size: 26, color: rgb(0.95, 0.85, 0.55), anim: .biku),
    "ウトウト":    WordStyle(text: "ウトウト", fontNames: MINCHO, size: 22, color: rgb(0.78, 0.82, 0.95), anim: .uto),
    "ぼー…":      WordStyle(text: "ぼー…", fontNames: MINCHO, size: 22, color: rgb(0.80, 0.80, 0.85), anim: .boo),
    "ムズムズ":    WordStyle(text: "ムズムズ", fontNames: MINCHO, size: 22, color: rgb(0.90, 0.88, 0.72), anim: .muzu),
    // メタ語（フィードバック受領）
    "チガウチガウ": WordStyle(text: "チガウチガウ", fontNames: GOTHIC, size: 26, color: rgb(0.72, 0.80, 0.92), anim: .chigau),
    "つかまえた！": WordStyle(text: "つかまえた！", fontNames: GOTHIC, size: 30, color: rgb(1.0, 0.85, 0.35), anim: .pita),
    // ── 形態バリアント（動作の質で揺らぐ語形）──
    // クリック族
    "ポチ":        WordStyle(text: "ポチ", fontNames: MINCHO, size: 24, color: rgb(1.0, 0.93, 0.95), anim: .pochi),
    "カチッ":      WordStyle(text: "カチッ", fontNames: GOTHIC, size: 29, color: rgb(0.90, 0.94, 1.0), anim: .pochi),
    "バチンッ":    WordStyle(text: "バチンッ", fontNames: GOTHIC, size: 36, color: rgb(1.0, 0.45, 0.40), anim: .pita),
    "グッ":        WordStyle(text: "グッ", fontNames: GOTHIC, size: 30, color: rgb(1.0, 0.67, 0.40), anim: .pochi),
    "ミギクリ…？": WordStyle(text: "ミギクリ…？", fontNames: MINCHO, size: 26, color: rgb(0.75, 0.88, 0.80), anim: .fumu),
    "ミギバシッ！": WordStyle(text: "ミギバシッ！", fontNames: GOTHIC, size: 32, color: rgb(0.45, 0.90, 0.60), anim: .pita),
    // ドロップ族
    "ポトッ":      WordStyle(text: "ポトッ", fontNames: MINCHO, size: 26, color: rgb(0.85, 0.92, 0.75), anim: .poi),
    "ポーイッ！":  WordStyle(text: "ポーイッ！", fontNames: GOTHIC, size: 38, color: rgb(0.72, 1.0, 0.50), anim: .poi),
    "ドサッ":      WordStyle(text: "ドサッ", fontNames: GOTHIC, size: 34, color: rgb(0.85, 0.66, 0.44), anim: .pita),
    // 段差族
    "コトッ":      WordStyle(text: "コトッ", fontNames: MINCHO, size: 23, color: rgb(0.90, 0.88, 0.84), anim: .kata),
    "ガタッ！":    WordStyle(text: "ガタッ！", fontNames: GOTHIC, size: 31, color: rgb(1.0, 0.78, 0.42), anim: .kata),
    // Enter族
    "たん":        WordStyle(text: "たん", fontNames: MINCHO, size: 24, color: rgb(0.95, 0.90, 1.0), anim: .tturn),
    "ターン！":    WordStyle(text: "ターン！", fontNames: GOTHIC, size: 34, color: rgb(1.0, 0.65, 0.38), anim: .tturn),
    "ッッターン！！": WordStyle(text: "ッッターン！！", fontNames: GOTHIC, size: 48, color: rgb(1.0, 0.42, 0.24), anim: .tturn),
    // タイピング族
    "ポチポチ":    WordStyle(text: "ポチポチ", fontNames: MINCHO, size: 25, color: rgb(0.93, 0.93, 0.98), anim: .kacha),
    "カタカタカタ": WordStyle(text: "カタカタカタ", fontNames: GOTHIC, size: 28, color: rgb(0.88, 0.92, 1.0), anim: .kacha),
    "ダダダダッ":  WordStyle(text: "ダダダダッ", fontNames: GOTHIC, size: 32, color: rgb(1.0, 0.50, 0.50), anim: .dadada),
]

func pickFont(_ names: [String], _ size: CGFloat) -> NSFont {
    for n in names { if let f = NSFont(name: n, size: size) { return f } }
    return NSFont.systemFont(ofSize: size, weight: .heavy)
}

// MARK: - 漫画文字ビュー（グリフの手描き風ゆらぎ＋ボイルアニメ）

final class MangaView: NSView {
    private struct CharSprite {
        let variants: [CGPath]        // 輪郭を揺らした3バリアント（8fpsで切替=ボイル）
        let fallback: NSAttributedString?  // グリフ取得に失敗した文字用
        let width: CGFloat            // 送り幅
        let height: CGFloat           // フォールバック描画の縦中央合わせ用
        let color: NSColor
    }

    private var chars: [CharSprite] = []
    private var anim: Anim = .soro
    private var capHeight: CGFloat = 20
    private var strokeW: CGFloat = 4
    // コミカル描き文字パラメータ（setWordでWordStyleから取り込む）
    private var cOutline: CGFloat = 0.5
    private var cGradient: CGFloat = 0.55
    private var cHalo: CGFloat = 0.6
    private var cRough: CGFloat = 0.2
    private var fontSize: CGFloat = 28
    var wordStart: CFTimeInterval = 0
    var dirX: CGFloat = 1  // スピード線・後傾の向き
    var intensity: CGFloat = 0.6  // 0..1 動きの強度（速度/打鍵レート/スクロール勢い）→ 文字サイズに反映

    // ── コミックエフェクト（BOOM!スタイルのバースト/フラッシュ/雲） ──
    static var comicFX = UserDefaults.standard.object(forKey: "comicFX") as? Bool ?? true
    // 高視認スタイル（2026-07-29 第二著者フィードバック）: どんな背景でも読めることを最優先。
    // 白文字＋濃グレーのドロップシャドウのみで描き、エフェクト・ハロー・グラデ・かすれを抑制する。
    // ボイルと語アニメは残す（描き文字の生命感は視認性を損なわない）。実験の表示スタイル条件も兼ねる
    static var legibleMode = UserDefaults.standard.bool(forKey: "legibleMode")
    enum EffectKind { case burst, flash, cloud, none }
    private var fx: EffectKind = .none
    private var fxOuter: [CGPath] = []   // ボイル3変種
    private var fxInner: [CGPath] = []
    private var stars: [(p: CGPoint, r: CGFloat, rot: CGFloat)] = []
    private var clouds: [(p: CGPoint, r: CGFloat)] = []
    private var fxTilt: CGFloat = 0
    private var fxFill = NSColor.yellow

    private static func effectKind(for anim: Anim) -> EffectKind {
        // うるささ調整（2026-07-16ユーザーフィードバック）: 速度系のフラッシュのみ残す。
        // burst/cloudの実装は温存（実験条件・デモ用に再有効化できる）
        switch anim {
        case .byuun, .dadada, .gaa, .sha: return .flash
        default: return .none
        }
    }

    // ギザギザ爆発バルーン（spikes本のトゲ、seedで決定的にジッター）
    private static func makeBurst(w: CGFloat, h: CGFloat, spikes: Int, seed: CGFloat,
                                  stretch: CGFloat = 1.0) -> CGPath {
        let path = CGMutablePath()
        let rx = (w / 2 + 30) * stretch
        let ry = h / 2 + 26
        for i in 0..<(spikes * 2) {
            let a = CGFloat(i) * .pi / CGFloat(spikes) - .pi / 2
            let jit = 0.8 + 0.25 * abs(sin(seed + CGFloat(i) * 2.7))
            let rad: CGFloat = i % 2 == 0 ? 1.0 * jit : 0.62 * (0.9 + 0.1 * cos(seed * 1.3 + CGFloat(i)))
            let pt = CGPoint(x: cos(a) * rx * rad, y: sin(a) * ry * rad)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }

    private func buildEffects(style: WordStyle, seed: CGFloat, totalW: CGFloat) {
        fx = (MangaView.comicFX && !MangaView.legibleMode) ? Self.effectKind(for: style.anim) : .none
        fxOuter = []; fxInner = []; stars = []; clouds = []
        guard fx != .none else { return }
        fxTilt = sin(seed * 3.7) * 0.09
        let h = style.size * 1.5
        switch fx {
        case .burst:
            fxFill = style.anim == .pita || style.anim == .tturn || style.anim == .gata
                ? rgb(1.0, 0.83, 0.20) : rgb(1.0, 0.62, 0.25)
            for v in 0..<3 {
                fxOuter.append(Self.makeBurst(w: totalW, h: h, spikes: 16, seed: seed + CGFloat(v) * 11))
                fxInner.append(Self.makeBurst(w: totalW * 0.82, h: h * 0.76, spikes: 12, seed: seed + CGFloat(v) * 7 + 3))
            }
            for i in 0..<6 {
                let a = CGFloat(i) / 6 * 2 * .pi + seed
                stars.append((CGPoint(x: cos(a) * (totalW / 2 + 52 + 18 * sin(seed + CGFloat(i))),
                                      y: sin(a) * (h / 2 + 44 + 12 * cos(seed + CGFloat(i) * 2))),
                              5 + 4 * abs(sin(seed + CGFloat(i) * 1.7)),
                              CGFloat(i) * 0.6))
            }
        case .flash:
            fxFill = rgb(1.0, 0.95, 0.55)
            for v in 0..<3 {
                fxOuter.append(Self.makeBurst(w: totalW, h: h * 0.8, spikes: 22, seed: seed + CGFloat(v) * 13, stretch: 1.35))
            }
        case .cloud:
            fxFill = NSColor.white
            let n = 10
            for i in 0..<n {
                let a = CGFloat(i) / CGFloat(n) * 2 * .pi
                let rx = totalW / 2 + 16
                let ry = h / 2 + 10
                clouds.append((CGPoint(x: cos(a) * rx, y: sin(a) * ry),
                               14 + 7 * abs(sin(seed + CGFloat(i) * 2.3))))
            }
        case .none: break
        }
    }

    // 5角星
    private static func starPath(r: CGFloat) -> CGPath {
        let p = CGMutablePath()
        for i in 0..<10 {
            let a = CGFloat(i) * .pi / 5 - .pi / 2
            let rad: CGFloat = i % 2 == 0 ? r : r * 0.45
            let pt = CGPoint(x: cos(a) * rad, y: sin(a) * rad)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    private func drawEffects(_ cg: CGContext, t: CFTimeInterval, cx: CGFloat, cy: CGFloat, scale: CGFloat) {
        guard fx != .none, !fxOuter.isEmpty || !clouds.isEmpty else { return }
        let boil = Int(t * 8) % 3
        cg.saveGState()
        cg.translateBy(x: cx, y: cy)
        cg.rotate(by: fxTilt)
        cg.scaleBy(x: scale, y: scale)
        switch fx {
        case .burst:
            let outer = fxOuter[boil]
            // 白フチ→本体→内側レイヤー→ハーフトーン
            cg.addPath(outer); cg.setLineWidth(9); cg.setLineJoin(.miter)
            cg.setStrokeColor(NSColor.white.cgColor); cg.strokePath()
            cg.addPath(outer); cg.setFillColor(fxFill.cgColor); cg.fillPath()
            cg.addPath(outer); cg.setLineWidth(3.5)
            cg.setStrokeColor(rgb(0.35, 0.15, 0.05).cgColor); cg.strokePath()
            let inner = fxInner[boil]
            cg.addPath(inner); cg.setFillColor(NSColor.white.withAlphaComponent(0.92).cgColor); cg.fillPath()
            // ハーフトーンドット（外周リングに帯状）
            cg.saveGState()
            cg.addPath(outer); cg.clip()
            cg.setFillColor(rgb(0.85, 0.25, 0.15).withAlphaComponent(0.35).cgColor)
            let bb = outer.boundingBox
            var yy = bb.minY
            var row = 0
            while yy < bb.maxY {
                var xx = bb.minX + (row % 2 == 0 ? 0 : 7)
                while xx < bb.maxX {
                    let distRatio = hypot(xx / (bb.width / 2), yy / (bb.height / 2))
                    if distRatio > 0.55 {   // 中心は空けて外周に帯
                        cg.fillEllipse(in: CGRect(x: xx - 2.2, y: yy - 2.2, width: 4.4, height: 4.4))
                    }
                    xx += 14
                }
                yy += 12
                row += 1
            }
            cg.restoreGState()
            // 散り星
            for st in stars {
                cg.saveGState()
                cg.translateBy(x: st.p.x, y: st.p.y)
                cg.rotate(by: st.rot + CGFloat(t) * 0.8)
                let sp = Self.starPath(r: st.r)
                cg.addPath(sp); cg.setFillColor(rgb(1.0, 0.83, 0.20).cgColor); cg.fillPath()
                cg.addPath(sp); cg.setLineWidth(1.2)
                cg.setStrokeColor(rgb(0.35, 0.15, 0.05).cgColor); cg.strokePath()
                cg.restoreGState()
            }
        case .flash:
            let outer = fxOuter[boil]
            cg.saveGState()
            cg.rotate(by: -0.10 * dirX)
            cg.addPath(outer); cg.setFillColor(fxFill.withAlphaComponent(0.92).cgColor); cg.fillPath()
            cg.addPath(outer); cg.setLineWidth(3)
            cg.setStrokeColor(rgb(0.45, 0.30, 0.05).cgColor); cg.strokePath()
            cg.restoreGState()
        case .cloud:
            for c in clouds {
                let wob = 1 + 0.08 * sin(CGFloat(t) * 3 + c.p.x)
                let r = c.r * wob
                let rect = CGRect(x: c.p.x - r, y: c.p.y - r, width: r * 2, height: r * 2)
                cg.setFillColor(NSColor.white.cgColor)
                cg.fillEllipse(in: rect)
                cg.setStrokeColor(rgb(0.55, 0.60, 0.75).cgColor)
                cg.setLineWidth(2)
                cg.strokeEllipse(in: rect)
            }
            // 中央を白で埋めて輪だけ雲にする
            let bb = CGRect(x: -(clouds.map { abs($0.p.x) }.max() ?? 60), y: -(clouds.map { abs($0.p.y) }.max() ?? 30),
                            width: 2 * (clouds.map { abs($0.p.x) }.max() ?? 60), height: 2 * (clouds.map { abs($0.p.y) }.max() ?? 30))
            cg.setFillColor(NSColor.white.cgColor)
            cg.fillEllipse(in: bb.insetBy(dx: 6, dy: 4))
        case .none: break
        }
        cg.restoreGState()
    }

    func setWord(_ style: WordStyle) {
        // 表示直前でのみ canonical → 現在言語の語形に解決（分類・形態生成は言語非依存のまま）
        let lang = VocabularyStore.shared.currentLang
        let text = DeliveredVocab.shared.localize(style.text, lang: lang)
            ?? VocabularyStore.shared.localize(style.text)
        var fontNames = style.fontNames
        if lang != "ja", let lf = LANG_FONTS[lang] {
            fontNames = style.fontNames == MINCHO ? lf.mincho : lf.gothic
        }
        let font = pickFont(fontNames, style.size)
        capHeight = font.capHeight
        strokeW = style.size * 0.12
        fontSize = style.size
        cOutline = style.outline; cGradient = style.gradient; cHalo = style.halo
        cRough = style.roughness
        chars = text.enumerated().map { (idx, ch) in
            if let (paths, adv) = Self.wobbleGlyph(ch, font: font, seed: idx,
                                                   pressure: style.pressure, taper: style.taper) {
                return CharSprite(variants: paths, fallback: nil, width: adv, height: 0, color: style.color)
            }
            let attrs: [NSAttributedString.Key: Any]
            if MangaView.legibleMode {
                let sh = NSShadow()
                sh.shadowOffset = NSSize(width: 2.5, height: -2.5)
                sh.shadowBlurRadius = 4
                sh.shadowColor = NSColor(white: 0.18, alpha: 0.95)
                attrs = [.font: font, .foregroundColor: NSColor.white, .shadow: sh]
            } else {
                attrs = [.font: font, .foregroundColor: style.color,
                         .strokeColor: NSColor.black, .strokeWidth: -5.5]
            }
            let attr = NSAttributedString(string: String(ch), attributes: attrs)
            let sz = attr.size()
            return CharSprite(variants: [], fallback: attr, width: sz.width, height: sz.height, color: style.color)
        }
        anim = style.anim
        wordStart = CACurrentMediaTime()
        let totalW = chars.reduce(0) { $0 + $1.width } + 3 * CGFloat(max(chars.count - 1, 0))
        buildEffects(style: style, seed: CGFloat(text.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 97),
                     totalW: totalW)
    }

    func clearWord() { chars = [] }

    // グリフのアウトラインを取り出し、筆圧・テーパー（BrushDeform）をかけた上で
    // 制御点を決定的ノイズで揺らした3バリアントを作る（ボイルごとに筆圧の位相も揺れる）
    private static func wobbleGlyph(_ ch: Character, font: NSFont, seed: Int,
                                    pressure: CGFloat = 0.45, taper: CGFloat = 0.35) -> ([CGPath], CGFloat)? {
        var utf16 = Array(String(ch).utf16)
        guard utf16.count == 1 else { return nil }
        var glyph: CGGlyph = 0
        guard CTFontGetGlyphsForCharacters(font, &utf16, &glyph, 1), glyph != 0,
              let base = CTFontCreatePathForGlyph(font, glyph, nil) else { return nil }
        let adv = CGFloat(CTFontGetAdvancesForGlyphs(font, .horizontal, &glyph, nil, 1))
        let amp = font.pointSize * 0.04

        var variants: [CGPath] = []
        for v in 0..<3 {
            let s = CGFloat(seed * 31 + v * 47)
            // 筆圧・テーパー: 輪郭を法線方向に太細させる（変種ごとに位相を変えて筆も沸く）
            let brushed = BrushDeform.apply(to: base, fontSize: font.pointSize,
                                            pressure: Double(pressure), taper: Double(taper),
                                            seed: s * 0.7)
            let m = CGMutablePath()
            func jit(_ p: CGPoint, _ salt: CGFloat) -> CGPoint {
                CGPoint(x: p.x + sin(p.y * 0.15 + s + salt) * amp,
                        y: p.y + cos(p.x * 0.17 + s * 1.3 + salt * 2.1) * amp)
            }
            brushed.applyWithBlock { elem in
                let e = elem.pointee
                switch e.type {
                case .moveToPoint: m.move(to: jit(e.points[0], 0))
                case .addLineToPoint: m.addLine(to: jit(e.points[0], 1))
                case .addQuadCurveToPoint: m.addQuadCurve(to: jit(e.points[1], 2), control: jit(e.points[0], 3))
                case .addCurveToPoint: m.addCurve(to: jit(e.points[2], 4), control1: jit(e.points[0], 5), control2: jit(e.points[1], 6))
                case .closeSubpath: m.closeSubpath()
                @unknown default: break
                }
            }
            variants.append(m)
        }
        return (variants, adv)
    }

    // ポップイン: 0 → 1.3 → 1 とオーバーシュートして登場
    private func popScale(_ u: Double) -> CGFloat {
        if u <= 0 { return 0.01 }
        return CGFloat(max(0.01, 1.0 - exp(-8.0 * u) * cos(11.0 * u)))
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !chars.isEmpty, let cg = NSGraphicsContext.current?.cgContext else { return }
        let t = CACurrentMediaTime()
        let u = t - wordStart
        let tracking: CGFloat = 3
        let total = chars.reduce(0) { $0 + $1.width } + tracking * CGFloat(chars.count - 1)
        var x = (bounds.width - total) / 2
        let cy = bounds.height / 2

        // コミックエフェクト（文字の背後）: 強度と同じスケールで呼吸する
        drawEffects(cg, t: t, cx: bounds.width / 2, cy: cy, scale: 0.8 + intensity * 1.1)

        // スピード線（ビューン/ダダダッ: 文字の後ろに流れる）
        if (anim == .byuun || anim == .dadada) && !MangaView.legibleMode {
            cg.saveGState()
            cg.setStrokeColor(NSColor.white.withAlphaComponent(0.85).cgColor)
            cg.setLineWidth(3)
            cg.setLineCap(.round)
            for k in 0..<3 {
                let ly = cy - 16 + CGFloat(k) * 16 + sin(CGFloat(t) * 9 + CGFloat(k)) * 3
                let len: CGFloat = 46 + CGFloat(k % 2) * 22
                let sx = dirX > 0 ? x - 14 : x + total + 14
                cg.move(to: CGPoint(x: sx, y: ly))
                cg.addLine(to: CGPoint(x: sx - dirX * len, y: ly))
            }
            cg.strokePath()
            cg.restoreGState()
        }

        // 語全体のオフセット
        var wordOX: CGFloat = 0
        switch anim {
        case .kyoro: wordOX = sin(CGFloat(t) * 13) * 10
        case .oro:   wordOX = sin(CGFloat(t) * 7) * 4
        case .bun:   wordOX = sin(CGFloat(t) * 18) * 16
        case .uro:   wordOX = sin(CGFloat(t) * 1.6) * 10
        default: break
        }

        for (i, c) in chars.enumerated() {
            let fi = CGFloat(i)
            let phase = CGFloat(t)
            var rot: CGFloat = 0
            var ox: CGFloat = 0
            var oy: CGFloat = 0
            var sx: CGFloat = 1
            var sy: CGFloat = 1
            var shear: CGFloat = 0

            switch anim {
            case .kyoro:
                rot = sin(phase * 13 + fi * 0.6) * 0.20
                oy = abs(sin(phase * 13 + fi * 0.6)) * 3
            case .oro:
                // sinハッシュによる決定的ジッター（毎フレーム乱数を使わない）
                ox = sin(phase * 37 + fi * 13.7) * 3
                oy = cos(phase * 41 + fi * 7.3) * 3
                rot = sin(phase * 29 + fi * 5.1) * 0.16
            case .soro:
                oy = sin(phase * 2.5 + fi * 0.9) * 3.5
                rot = sin(phase * 2.5 + fi * 0.9) * 0.05
            case .jiri:
                // にじり寄る: 小刻みな震え + 周期的に一歩進む
                ox = max(0, sin(phase * 5)) * 3 + sin(phase * 25 + fi) * 0.8
                oy = sin(phase * 23 + fi * 1.7) * 0.6
            case .guru:
                rot = phase * 7 + fi * 0.8   // 文字自体が回り続ける
                oy = sin(phase * 6 + fi) * 4
            case .kuru:
                rot = phase * 10 + fi * 1.2  // 小さく速い回転
                oy = sin(phase * 5 + fi) * 3
            case .byuun:
                shear = 0.34 * dirX
                sx = 1.15
                ox = -dirX * fi * 2.0
            case .pita:
                // 急停止の衝撃: 強いオーバーシュートで着地して静止
                let s = CGFloat(max(0.01, 1.0 - exp(-9.0 * u) * cos(8.0 * u) * 1.15))
                sx = s; sy = s
            case .puru:
                ox = sin(phase * 45 + fi * 2.0) * 2.5
                oy = cos(phase * 40 + fi * 1.3) * 2.0
            case .suu:
                oy = sin(phase * 2 + fi * 0.5) * 1.5
                ox = fi * 1.5
            case .sui:
                // 波が文字列を伝っていく
                oy = sin(phase * 4 - fi * 1.1) * 5
                rot = cos(phase * 4 - fi * 1.1) * 0.08
            case .bun:
                rot = sin(phase * 18 + fi * 0.3) * 0.30
            case .pyon:
                // 跳ねる + スクワッシュ&ストレッチ
                let hop = abs(sin(phase * 7 + fi * 0.9))
                oy = hop * 10
                sy = 1 + (hop - 0.5) * 0.25
                sx = 1 - (hop - 0.5) * 0.15
            case .dadada:
                ox = sin(phase * 50 + fi * 9) * 3 - dirX * fi * 2.5
                oy = cos(phase * 47 + fi * 5) * 3
                rot = sin(phase * 60 + fi * 3) * 0.08
            case .uro:
                rot = sin(phase * 3 + fi) * 0.12
                oy = sin(phase * 2.3 + fi * 0.5) * 2
            case .fumu:
                // うなずく
                rot = sin(phase * 4 + fi * 0.3) * 0.12
                oy = -abs(sin(phase * 4 + fi * 0.3)) * 3
            case .jiro:
                // ねめ回すように文字が交互に膨らむ
                let g = sin(phase * 6 + fi * 1.5)
                sx = 1 + g * 0.10; sy = 1 + g * 0.10
                rot = sin(phase * 2.5) * 0.06
            case .doki:
                // 心拍: ドッ・ドッと2拍で膨らむ
                let beat = pow(max(0, sin(phase * 6)), 3)
                sx = 1 + beat * 0.18; sy = 1 + beat * 0.18
            case .kacha:
                // タイピング: 文字が交互にカタカタ沈む
                oy = -abs(sin(phase * 26 + fi * 1.6)) * 4
                rot = sin(phase * 26 + fi * 1.6) * 0.05
            case .tturn:
                // 圧倒的ッターン！: 衝撃着地 + 減衰する横シェイク
                let s = CGFloat(max(0.01, 1.0 - exp(-9.0 * u) * cos(8.0 * u) * 1.25))
                sx = s; sy = s
                ox = sin(phase * 42) * 4 * CGFloat(exp(-3.0 * u))
            case .suru:
                // なめらかにスクロール: 波が流れ落ちる
                oy = sin(phase * 5 - fi * 0.9) * 4
            case .gaa:
                // 勢いよくスクロール: 縦に流れる強い揺れ
                oy = sin(phase * 18 + fi * 0.7) * 6
                rot = sin(phase * 18 + fi * 0.7) * 0.1
            case .gaba:
                // ピンチアウト: 文字が外へ広がりながら膨らむ
                let center = CGFloat(chars.count - 1) / 2
                let breathe = 0.5 + 0.5 * sin(phase * 3)
                ox = (fi - center) * 6 * breathe
                sx = 1 + breathe * 0.18; sy = 1 + breathe * 0.18
            case .kyu:
                // ピンチイン: 中心へきゅっと縮む
                let center = CGFloat(chars.count - 1) / 2
                let squeeze = 0.5 + 0.5 * sin(phase * 6)
                ox = -(fi - center) * 4 * squeeze
                sx = 1 - squeeze * 0.12; sy = 1 - squeeze * 0.12
            case .shuru:
                // 巻き戻し: 波が上へ巻き上がっていく
                oy = sin(phase * 7 + fi * 1.1) * 4 + 2
                rot = sin(phase * 7 + fi * 1.1) * 0.10
            case .sha:
                // ページ送り: 鋭い横フリック（前傾＋文字が流れる）
                shear = 0.30 * dirX
                ox = fi * 2.5 * dirX
                oy = sin(phase * 20 + fi) * 1.5
            case .guri:
                // 回転ジェスチャー: 大きく左右にねじる
                rot = sin(phase * 9 + fi * 0.4) * 0.45
                oy = abs(sin(phase * 9 + fi * 0.4)) * 3
            case .pochi:
                // 押し込みバウンス: ぐっと沈んで戻る
                let press = CGFloat(exp(-7.0 * u) * cos(9.0 * u))
                oy = -6 * press
                sx = 1 - 0.18 * press; sy = 1 - 0.18 * press
            case .kachi2:
                // ダブルクリック: 2連パルス
                let p1 = CGFloat(exp(-160 * (u - 0.02) * (u - 0.02)))
                let p2 = CGFloat(exp(-160 * (u - 0.18) * (u - 0.18)))
                let s = 1 + 0.28 * (p1 + p2)
                sx = s; sy = s
            case .migi:
                // 右クリック: 右に傾いて飛び出す
                rot = -0.14
                ox = fi * 2 + 12 * CGFloat(exp(-5.0 * u))
                sy = 1 + 0.1 * CGFloat(exp(-6.0 * u))
            case .gui:
                // 引っぱる: 進行方向へぐいっぐいっと引く
                ox = dirX * (3 + 4 * abs(sin(phase * 5))) + sin(phase * 8 + fi) * 2
                rot = dirX * 0.08 * sin(phase * 5)
            case .zuru:
                // 引きずる: 重く沈んで文字が遅れてついてくる
                ox = -dirX * fi * 1.8
                oy = -2 + sin(phase * 6 + fi) * 1.5
                rot = dirX * 0.05
            case .kata:
                // 段差に引っかかる: 一度だけコトッと傾いて収まる
                rot = 0.15 * CGFloat(exp(-6.0 * u) * cos(18.0 * u))
                oy = -3 * CGFloat(exp(-8.0 * u))
            case .gata:
                // 連続段差: 強いガタつき
                ox = sin(phase * 32 + fi * 1.2) * 4
                oy = abs(cos(phase * 28 + fi)) * 3
                rot = sin(phase * 30 + fi) * 0.1
            case .poi:
                // ドロップ: 放り投げられて放物線を描き、くるっと回って着地
                let uu = CGFloat(min(u / 0.6, 1.0))
                oy = 34 * 4 * uu * (1 - uu)
                rot = uu * 0.5 * dirX
                ox = dirX * uu * 10 + fi * 1.5 * dirX
            case .iki:
                // 寝息: ゆっくり膨らんで縮む呼吸
                let breath = 1 + 0.06 * sin(phase * 1.6 + fi * 0.2)
                sx = breath; sy = breath
                oy = sin(phase * 1.6) * 1.5
            case .jiwa:
                // じわじわ: ごくゆっくり滲み広がる
                let seep = 1 + 0.04 * sin(phase * 0.9 + fi * 0.5)
                sx = seep; sy = seep
                ox = fi * 0.8 * sin(phase * 0.7)
            case .sowa:
                // そわそわ: 落ち着かない小さな身じろぎ
                ox = sin(phase * 5 + fi * 2.1) * 1.8
                oy = cos(phase * 4.3 + fi * 1.3) * 1.2
                rot = sin(phase * 3.7 + fi) * 0.05
            case .moji:
                // もじもじ: 内股にねじれる
                rot = sin(phase * 2.8 + fi * 0.9) * 0.10
                ox = -sin(phase * 2.8 + fi * 0.9) * 1.5
                sy = 1 - 0.04 * abs(sin(phase * 2.8))
            case .biku:
                // ビクビクッ: 静止の中で突然の痙攣（約1.6秒周期の鋭いスパイク）
                let cyc = phase.truncatingRemainder(dividingBy: 1.6)
                let spike = CGFloat(exp(-18.0 * Double(cyc)))
                ox = spike * 6 * sin(fi * 3 + phase)
                oy = spike * 8
                rot = spike * 0.18 * (fi.truncatingRemainder(dividingBy: 2) == 0 ? 1 : -1)
            case .uto:
                // ウトウト: 舟をこぐ——ゆっくり傾いてカクンと戻る
                let nod = phase.truncatingRemainder(dividingBy: 3.2)
                let lean = min(nod / 2.6, 1.0) * 0.22
                let snap = nod > 2.6 ? CGFloat(exp(-8.0 * Double(nod - 2.6))) : 1.0
                rot = -lean * snap
                oy = -lean * 6 * snap
            case .boo:
                // ぼー…: ほとんど動かず、ごくゆっくり漂う
                ox = sin(phase * 0.5 + fi) * 1.2
                oy = cos(phase * 0.4) * 1.0
            case .muzu:
                // ムズムズ: 動きたくてうずうず（細かく波打つ）
                oy = sin(phase * 9 + fi * 1.8) * 1.6
                rot = sin(phase * 7 + fi) * 0.06
            case .chigau:
                // チガウチガウ: 首を横に振る（減衰する左右シェイク）
                let damp = CGFloat(exp(-1.8 * u))
                ox = sin(phase * 11 + fi * 0.4) * 7 * damp
                rot = sin(phase * 11 + fi * 0.4) * 0.09 * damp
            }

            // ポップイン（文字ごとに時差登場。衝撃系は独自の登場演出を持つので除外）
            if anim != .pita && anim != .tturn {
                let pop = popScale(u - Double(i) * 0.045)
                sx *= pop; sy *= pop
            }

            // 強度→文字サイズ（弱い動き0.8倍〜激しい動き1.9倍。ストロークも一緒にスケール）
            let sizeMul = 0.8 + intensity * 1.1
            sx *= sizeMul; sy *= sizeMul

            let cx = x + c.width / 2 + ox + wordOX
            let cyy = cy + oy

            cg.saveGState()
            cg.translateBy(x: cx, y: cyy)
            cg.rotate(by: rot)
            if shear != 0 {
                cg.concatenate(CGAffineTransform(a: 1, b: 0, c: shear, d: 1, tx: 0, ty: 0))
            }
            cg.scaleBy(x: sx, y: sy)

            if !c.variants.isEmpty {
                // ボイル: 8fpsで3バリアントを巡回
                let path = c.variants[(Int(t * 8) + i) % c.variants.count]
                cg.translateBy(x: -c.width / 2, y: -capHeight / 2)
                if MangaView.legibleMode {
                    // 高視認: 白文字＋濃グレーのドロップシャドウのみ（背景を問わず読める最小構成）
                    cg.saveGState()
                    cg.setShadow(offset: CGSize(width: 2.5, height: -2.5), blur: 4,
                                 color: NSColor(white: 0.18, alpha: 0.95).cgColor)
                    cg.addPath(path)
                    cg.setFillColor(NSColor.white.cgColor)
                    cg.fillPath()
                    cg.restoreGState()
                } else if MangaView.comicFX {
                    // コミカル描き文字: 影 → 白ハロー → 極太黒フチ → 縦グラデ塗り（BOOM!スタイル）
                    let outlineW = strokeW * (1.0 + cOutline * 1.6)
                    // ドロップシャドウ
                    cg.saveGState()
                    cg.translateBy(x: 2.8, y: -2.8)
                    cg.addPath(path)
                    cg.setFillColor(NSColor.black.withAlphaComponent(0.5).cgColor)
                    cg.fillPath()
                    cg.restoreGState()
                    // 白ハロー（フチの外側に白い縁取り）
                    if cHalo > 0.05 {
                        cg.addPath(path)
                        cg.setLineWidth(outlineW + cHalo * 9)
                        cg.setLineJoin(.round)
                        cg.setStrokeColor(NSColor.white.cgColor)
                        cg.strokePath()
                    }
                    // 極太黒フチ
                    cg.addPath(path)
                    cg.setLineWidth(outlineW)
                    cg.setLineJoin(.round)
                    cg.setStrokeColor(NSColor.black.cgColor)
                    cg.strokePath()
                    // 縦グラデ塗り（上=本来色, 下=暗色）— グリフでクリップ
                    cg.saveGState()
                    cg.addPath(path)
                    cg.clip()
                    let bb = path.boundingBoxOfPath
                    let dark = c.color.blended(withFraction: 0.45 * cGradient, of: .black) ?? c.color
                    let cs = CGColorSpaceCreateDeviceRGB()
                    if bb.height > 1,
                       let grad = CGGradient(colorsSpace: cs,
                                             colors: [c.color.cgColor, dark.cgColor] as CFArray,
                                             locations: [0, 1]) {
                        cg.drawLinearGradient(grad, start: CGPoint(x: 0, y: bb.maxY),
                                              end: CGPoint(x: 0, y: bb.minY), options: [])
                    } else {
                        cg.setFillColor(c.color.cgColor); cg.fill(bb)
                    }
                    // かすれ: グリフ内を走る細い削り筋（ボイル変種ごとに揺れる）
                    if cRough > 0.03 {
                        cg.setBlendMode(.destinationOut)
                        cg.setLineCap(.round)
                        let vseed = CGFloat((Int(t * 8) + i) % 3) * 5.1 + CGFloat(i) * 1.7
                        for (k, ln) in BrushDeform.scratchLines(bbox: bb, fontSize: fontSize,
                                                                roughness: Double(cRough), seed: vseed).enumerated() {
                            cg.setLineWidth(ln.width)
                            cg.setLineDash(phase: 0,
                                           lengths: BrushDeform.scratchDash(fontSize: fontSize, seed: vseed, index: k))
                            cg.move(to: ln.from); cg.addLine(to: ln.to)
                            cg.strokePath()
                        }
                        cg.setLineDash(phase: 0, lengths: [])
                        cg.setBlendMode(.normal)
                    }
                    cg.restoreGState()
                } else {
                    cg.addPath(path)
                    cg.setLineWidth(strokeW)
                    cg.setLineJoin(.round)
                    cg.setStrokeColor(NSColor.black.cgColor)
                    cg.strokePath()
                    cg.addPath(path)
                    cg.setFillColor(c.color.cgColor)
                    cg.fillPath()
                }
            } else if let attr = c.fallback {
                attr.draw(at: NSPoint(x: -c.width / 2, y: -c.height / 2))
            }
            cg.restoreGState()

            x += c.width + tracking
        }
    }
}

// MARK: - 背景コンテンツ検出（Accessibility・オプトイン）

final class ContextSensor {
    private(set) var enabled = false
    private(set) var role = ""
    private var lastPoll: CFTimeInterval = 0
    private let systemWide = AXUIElementCreateSystemWide()

    // Accessibility権限を確認（未許可なら1回だけシステムのプロンプトを出す）
    func enable() -> Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        enabled = AXIsProcessTrustedWithOptions(opts)
        if !enabled { role = "" }
        return enabled
    }

    func disable() {
        enabled = false
        role = ""
    }

    // 5Hzでカーソル下の要素ロールを取得（AXは左上原点なのでY反転）
    func poll(at p: NSPoint, now: CFTimeInterval) {
        guard enabled, now - lastPoll > 0.2 else { return }
        lastPoll = now
        guard let primary = NSScreen.screens.first else { return }
        let axY = primary.frame.maxY - p.y
        var elRef: AXUIElement?
        if AXUIElementCopyElementAtPosition(systemWide, Float(p.x), Float(axY), &elRef) == .success,
           let el = elRef {
            var roleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &roleRef) == .success,
               let r = roleRef as? String {
                role = r
                return
            }
        }
        role = ""
    }

    // 低速で「見ている/迷っている」ときだけ文脈語を出す
    func contextWord(speed: CGFloat) -> String? {
        guard enabled, speed > 0.15, speed < 3.5 else { return nil }
        switch role {
        case "AXStaticText", "AXTextArea", "AXTextField", "AXWebArea":
            return "フムフム"
        case "AXImage", "AXCell":
            return "ジロジロ"
        case "AXButton", "AXLink", "AXPopUpButton", "AXCheckBox", "AXRadioButton", "AXMenuItem":
            return "ドキドキ"
        default:
            return nil
        }
    }
}

// MARK: - キャレット位置検出（打鍵語を「打っている場所」に出す）
//
// 打鍵中の視線はテキストキャレットにあり、マウスカーソルは無関係な場所に置き去りに
// なっていることが多い。打鍵語をマウス位置に出すと「変な空間に飛ぶ」ので、
// AXでフォーカス要素のキャレット矩形を取り、その近くに出す。取れないアプリでは
// フォーカスウィンドウ中央下→マウス位置の順でフォールバック。
final class CaretSensor {
    private let systemWide = AXUIElementCreateSystemWide()
    private var cached: NSPoint?
    private var cachedAt: CFTimeInterval = -10

    /// 打鍵語のアンカー（Cocoa座標）。0.3sキャッシュ。
    /// 優先順: キャレット矩形 → フォーカス要素内のマウス（クリック位置≈キャレット）→
    ///         フォーカス要素の枠 → フォーカスウィンドウ
    func anchor(now: CFTimeInterval, mouse: NSPoint) -> NSPoint? {
        if now - cachedAt < 0.3 { return cached }
        cachedAt = now
        cached = caretPoint() ?? elementAnchor(mouse: mouse) ?? focusedWindowPoint()
        return cached
    }

    /// キャレット矩形非対応アプリ（Electron等）用: フォーカス中のテキスト要素の枠。
    /// テキスト欄はクリックしてから打つことが多く、マウスが要素内ならそこが最良の近似
    private func elementAnchor(mouse: NSPoint) -> NSPoint? {
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString,
                                            &focusedRef) == .success,
              let focused = focusedRef, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let el = focused as! AXUIElement
        var posRef: CFTypeRef?, sizeRef: CFTypeRef?
        var pos = CGPoint.zero, size = CGSize.zero
        guard AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let pv = posRef, CFGetTypeID(pv) == AXValueGetTypeID(),
              let sv = sizeRef, CFGetTypeID(sv) == AXValueGetTypeID(),
              AXValueGetValue(pv as! AXValue, .cgPoint, &pos),
              AXValueGetValue(sv as! AXValue, .cgSize, &size),
              size.width > 1, size.height > 1 else { return nil }
        guard let primary = NSScreen.screens.first else { return nil }
        // AX(左上原点)→Cocoa枠
        let frame = NSRect(x: pos.x, y: primary.frame.maxY - pos.y - size.height,
                           width: size.width, height: size.height)
        if NSPointInRect(mouse, frame) { return mouse }   // クリックした場所≈キャレット
        // 要素の中央上寄り（1行フィールドなら実質その位置、大きなエディタでも本文寄り）
        return axToCocoa(CGRect(x: pos.x + size.width / 2 - 1,
                                y: pos.y + min(size.height * 0.35, 120),
                                width: 2, height: 2))
    }

    private func axToCocoa(_ r: CGRect) -> NSPoint? {
        guard let primary = NSScreen.screens.first else { return nil }
        // AXは全ディスプレイ共通の左上原点。CocoaはprimaryのmaxYからY反転
        let p = NSPoint(x: r.midX, y: primary.frame.maxY - r.maxY)
        // AX未実装アプリはゼロ座標や座標系違いのゴミ矩形を返す（→画面はじに飛ぶ）。
        // 実在スクリーン内に無い点は捨てて次のフォールバックへ
        guard NSScreen.screens.contains(where: { NSPointInRect(p, $0.frame.insetBy(dx: -8, dy: -8)) })
        else { return nil }
        return p
    }

    private func caretPoint() -> NSPoint? {
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString,
                                            &focusedRef) == .success,
              let focused = focusedRef, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let el = focused as! AXUIElement
        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXSelectedTextRangeAttribute as CFString,
                                            &rangeRef) == .success,
              let rangeVal = rangeRef, CFGetTypeID(rangeVal) == AXValueGetTypeID() else { return nil }
        var boundsRef: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
                  el, kAXBoundsForRangeParameterizedAttribute as CFString,
                  rangeVal, &boundsRef) == .success,
              let bv = boundsRef, CFGetTypeID(bv) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(bv as! AXValue, .cgRect, &rect),
              rect.origin.x.isFinite, rect.origin.y.isFinite,
              rect.width.isFinite, rect.height.isFinite,
              rect.origin != .zero,            // 原点ゼロ=未実装アプリのゴミ矩形の定番
              rect.height > 0, rect.height < 200 else { return nil }
        return axToCocoa(rect)
    }

    private func focusedWindowPoint() -> NSPoint? {
        var appRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString,
                                            &appRef) == .success,
              let app = appRef, CFGetTypeID(app) == AXUIElementGetTypeID() else { return nil }
        var winRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app as! AXUIElement, kAXFocusedWindowAttribute as CFString,
                                            &winRef) == .success,
              let win = winRef, CFGetTypeID(win) == AXUIElementGetTypeID() else { return nil }
        var posRef: CFTypeRef?, sizeRef: CFTypeRef?
        var pos = CGPoint.zero, size = CGSize.zero
        guard AXUIElementCopyAttributeValue(win as! AXUIElement, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(win as! AXUIElement, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let pv = posRef, CFGetTypeID(pv) == AXValueGetTypeID(),
              let sv = sizeRef, CFGetTypeID(sv) == AXValueGetTypeID(),
              AXValueGetValue(pv as! AXValue, .cgPoint, &pos),
              AXValueGetValue(sv as! AXValue, .cgSize, &size), size.width > 1 else { return nil }
        // ウィンドウの中央・下1/3あたり（本文が見えている領域の目安）
        return axToCocoa(CGRect(x: pos.x + size.width / 2 - 1, y: pos.y + size.height * 0.62,
                                width: 2, height: 2))
    }
}

// MARK: - キーボード検出（オプトイン・押鍵の事実のみ／内容は一切参照しない）

final class KeySensor {
    private(set) var enabled = false
    private var monitor: Any?
    private(set) var lastKeyTime: CFTimeInterval = -10
    private(set) var typingRate: CGFloat = 0   // 打鍵/秒のEMA（「強さ」の代理指標）
    var pendingReturn = false

    func enable() -> Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(opts) else { return false }
        // 2026-07-31: 新しいmacOSではグローバルキー監視にアクセシビリティと別枠の
        // 「入力監視」(Input Monitoring)が必要。無許可だとモニタは付くがイベントが届かない
        if IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) != kIOHIDAccessTypeGranted {
            IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)   // システム設定へ誘導するプロンプト
            return false
        }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] ev in
            guard let self else { return }
            // どのキーか・文字内容は参照しない。Return/Enterの判別と押鍵時刻のみ
            let now = CACurrentMediaTime()
            if ev.keyCode == 36 || ev.keyCode == 76 {
                self.pendingReturn = true
            }
            let interval = now - self.lastKeyTime
            if interval < 2.0 {
                self.typingRate = self.typingRate * 0.8 + CGFloat(1.0 / max(interval, 0.05)) * 0.2
            } else {
                self.typingRate = 1.5   // 打ち始めは控えめから
            }
            self.lastKeyTime = now
        }
        enabled = monitor != nil
        return enabled
    }

    func disable() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
        enabled = false
        pendingReturn = false
    }
}

// MARK: - トラックパッド検出（オプトイン・2本指スクロールとピンチ）

final class TouchSensor {
    private(set) var enabled = false
    private var monitors: [Any] = []
    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private(set) var lastScrollTime: CFTimeInterval = -10
    private(set) var scrollRate: CGFloat = 0     // |Δ|のEMA（勢いの推定）
    fileprivate var scrollDX: CGFloat = 0        // 符号付きΔのEMA（方向の推定）
    fileprivate var scrollDY: CGFloat = 0
    fileprivate var lastMagnifyTime: CFTimeInterval = -10
    fileprivate var magAccum: CGFloat = 0        // ジェスチャー内の累積（単発イベントのノイズ対策）
    fileprivate var lastRotateTime: CFTimeInterval = -10
    fileprivate var rotAccum: CGFloat = 0

    fileprivate func feedMagnify(_ delta: CGFloat, at now: CFTimeInterval) {
        if now - lastMagnifyTime > 0.6 { magAccum = 0 }
        magAccum += delta
        lastMagnifyTime = now
    }

    fileprivate func feedRotate(_ delta: CGFloat, at now: CFTimeInterval) {
        if now - lastRotateTime > 0.6 { rotAccum = 0 }
        rotAccum += delta
        lastRotateTime = now
    }

    func enable() -> Bool {
        #if !APPSTORE
        // スクロールのグローバル監視自体は無権限で動くが、magnify/rotateの
        // CGEventTapがAccessibilityを要するためフル版ではまとめてゲートする。
        // App Store版はAccessibilityを要求できないのでスクロールのみ・ゲートなし
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(opts) else { return false }
        #endif

        if let m = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel, handler: { [weak self] ev in
            guard let self else { return }
            let now = CACurrentMediaTime()
            // 慣性スクロール（momentum）は除外し、指が触れている間だけ反応する
            guard ev.momentumPhase == [] else { return }
            // ズーム意図のフォールバック: ctrl/option/cmd + スクロールはズーム操作の慣習
            if !ev.modifierFlags.intersection([.control, .option, .command]).isEmpty {
                self.feedMagnify(ev.scrollingDeltaY * 0.01, at: now)
            } else {
                self.scrollRate = self.scrollRate * 0.7 + (abs(ev.scrollingDeltaY) + abs(ev.scrollingDeltaX)) * 0.3
                self.scrollDX = self.scrollDX * 0.7 + ev.scrollingDeltaX * 0.3
                self.scrollDY = self.scrollDY * 0.7 + ev.scrollingDeltaY * 0.3
                self.lastScrollTime = now
            }
        }) { monitors.append(m) }

        // magnify/rotate はNSEventのグローバル監視では配られない —
        // より低層の listen-only CGEventTap で拾う（NSEventType: magnify=30, rotate=18）
        let mask: CGEventMask = (1 << 30) | (1 << 18)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, cgEvent, refcon in
                if let refcon, let ns = NSEvent(cgEvent: cgEvent) {
                    let sensor = Unmanaged<TouchSensor>.fromOpaque(refcon).takeUnretainedValue()
                    let now = CACurrentMediaTime()
                    if ns.type == .magnify {
                        sensor.feedMagnify(ns.magnification, at: now)
                    } else if ns.type == .rotate {
                        sensor.feedRotate(CGFloat(ns.rotation), at: now)
                    }
                }
                return Unmanaged.passUnretained(cgEvent)
            },
            userInfo: refcon)
        if let tap {
            tapSource = CFMachPortCreateRunLoopSource(nil, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), tapSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }

        enabled = !monitors.isEmpty || tap != nil
        return enabled
    }

    func disable() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors = []
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), tapSource, .commonModes) }
            CFMachPortInvalidate(tap)
        }
        tap = nil
        tapSource = nil
        enabled = false
    }

    // ジェスチャーごとに語り分け（優先度: ピンチ > 回転 > スクロール方向別）
    func touchWord(now: CFTimeInterval) -> String? {
        guard enabled else { return nil }
        if now - lastMagnifyTime < 0.5 && abs(magAccum) > 0.02 {
            return magAccum > 0 ? "ガバーッ" : "キュッ"
        }
        if now - lastRotateTime < 0.5 && abs(rotAccum) > 4 {
            return "グリグリ"
        }
        if now - lastScrollTime < 0.35 {
            if abs(scrollDX) > abs(scrollDY) * 1.5 { return "シャッ" }          // 横=ページ送り
            if scrollDY > 2 { return "シュルシュル" }                            // 上に戻る
            return scrollRate > 18 ? "ガーッ" : "スルスル"                       // 読み進む
        }
        return nil
    }

    var active: Bool {
        let now = CACurrentMediaTime()
        return enabled && (now - lastScrollTime < 1.0 || now - lastMagnifyTime < 1.0 || now - lastRotateTime < 1.0)
    }
}

// MARK: - クリック検出（権限不要・クリックの事実のみ）

final class ClickSensor {
    private(set) var enabled = false
    private var monitors: [Any] = []
    var pendingWord: String?
    var pendingFamily: String?   // 族アンカー生成用（click/drop。右クリックはnil=着せ替えない）
    private(set) var dragging = false
    private(set) var dragDistance: CGFloat = 0
    // 動作の質（形態生成用）— tickが毎フレーム更新
    var currentSpeed: CGFloat = 0
    var currentIdle: CGFloat = 0
    private var downTime: CFTimeInterval = -10
    private var dragStart: CFTimeInterval = -10
    private(set) var isDown = false
    var heldLongFired = false

    var pressDuration: CFTimeInterval { isDown ? CACurrentMediaTime() - downTime : 0 }
    var dragDuration: CFTimeInterval { dragging ? CACurrentMediaTime() - dragStart : 0 }

    func enable() -> Bool {
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown, handler: { [weak self] ev in
            guard let self else { return }
            // 語形は接近速度・連打数から生成（動作の質→形態）
            self.pendingWord = OnomatopeMorphology.clickWord(
                approachSpeed: self.currentSpeed, pressDuration: 0, clickCount: ev.clickCount)
            self.pendingFamily = "click"
            self.dragDistance = 0
            self.downTime = CACurrentMediaTime()
            self.isDown = true
            self.heldLongFired = false
        }) { monitors.append(m) }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .rightMouseDown, handler: { [weak self] _ in
            guard let self else { return }
            self.pendingWord = OnomatopeMorphology.rightClickWord(
                approachSpeed: self.currentSpeed, dwellBefore: self.currentIdle)
            self.pendingFamily = nil   // ミギクリ系はUIメタ語なので着せ替えない
        }) { monitors.append(m) }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged, handler: { [weak self] ev in
            guard let self else { return }
            self.dragDistance += abs(ev.deltaX) + abs(ev.deltaY)
            if self.dragDistance > 12, !self.dragging {
                self.dragging = true
                self.dragStart = CACurrentMediaTime()   // ドラッグ開始時刻（ドロップ語形用）
            }
        }) { monitors.append(m) }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp, handler: { [weak self] _ in
            guard let self else { return }
            if self.dragging {
                // ドロップ！ 放す速度と運んだ時間で語形が揺らぐ
                self.pendingWord = OnomatopeMorphology.dropWord(
                    releaseSpeed: self.currentSpeed,
                    dragDuration: CACurrentMediaTime() - self.dragStart)
                self.pendingFamily = "drop"
            }
            self.dragging = false
            self.isDown = false
        }) { monitors.append(m) }
        enabled = !monitors.isEmpty
        return enabled
    }

    func disable() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors = []
        enabled = false
        pendingWord = nil
        dragging = false
    }
}

// MARK: - 違和感フィードバック（右クリック2連打=「違う」・権限不要・常時）

final class RejectSensor {
    private var monitor: Any?
    private var lastRightAt: CFTimeInterval = -10
    var pendingReject = false

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .rightMouseDown) { [weak self] _ in
            guard let self else { return }
            let now = CACurrentMediaTime()
            if now - self.lastRightAt < 0.6 {
                self.pendingReject = true
                self.lastRightAt = -10
            } else {
                self.lastRightAt = now
            }
        }
    }
}

/// 否定フィードバックの追記ログ（feedback.jsonl・ローカルのみ）
final class FeedbackLog {
    static let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("OnomatopeCursor/feedback.jsonl")

    static func append(_ rec: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: rec) else { return }
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile()
            h.write(data)
            h.write(Data([0x0A]))
            try? h.close()
        }
    }
}

// MARK: - ウィンドウ段差検出（権限不要・窓の矩形のみ）

final class EdgeSensor {
    private var rects: [(pid: Int, rect: CGRect)] = []
    private var lastRefresh: CFTimeInterval = 0
    private var lastCross: CFTimeInterval = -10
    private var crossTimes: [CFTimeInterval] = []
    private var prevPoint: CGPoint?

    // 0.5秒ごとに画面上のウィンドウ矩形をキャッシュ（タイトル等は取得しない）
    private func refresh(now: CFTimeInterval) {
        guard now - lastRefresh > 0.5 else { return }
        lastRefresh = now
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                    kCGNullWindowID) as? [[String: Any]] else { return }
        rects = list.compactMap { info in
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  let pid = info[kCGWindowOwnerPID as String] as? Int,
                  let b = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = b["X"], let y = b["Y"], let w = b["Width"], let h = b["Height"],
                  w > 60, h > 60 else { return nil }
            return (pid, CGRect(x: x, y: y, width: w, height: h))
        }
    }

    // その点で「見えている」最前面ウィンドウの所有アプリ（rectsは前面→背面順）
    // PID単位にするのは、Electron等が透明な子ウィンドウを重ねるため
    // （Slackの上で動かすだけで内部境界をまたいでしまう問題への対策）。
    private func topOwner(of p: CGPoint) -> Int? {
        for e in rects where e.rect.contains(p) { return e.pid }
        return nil
    }

    /// カーソル（Cocoa座標）を渡し、【見えている・アプリ間の】窓の縁をまたいだら語を返す。
    /// 隠れた窓の縁・同一アプリ内部の子ウィンドウ境界では鳴らない
    /// （トレードオフ: 同一アプリの2枚の窓の境界も鳴らない）。
    func check(cocoaPoint p: NSPoint, speed: CGFloat, now: CFTimeInterval) -> String? {
        refresh(now: now)
        guard let primary = NSScreen.screens.first else { return nil }
        let cur = CGPoint(x: p.x, y: primary.frame.maxY - p.y)   // CG座標（左上原点）へ
        defer { prevPoint = cur }
        guard let prev = prevPoint, speed > 3, now - lastCross > 0.25 else { return nil }

        guard topOwner(of: prev) != topOwner(of: cur) else { return nil }
        lastCross = now
        crossTimes.append(now)
        crossTimes.removeAll { now - $0 > 0.9 }
        // またぎ方（速度・連続性）で語形が揺らぐ
        return OnomatopeMorphology.edgeWord(speed: speed, recentCrossings: crossTimes.count)
    }
}

// MARK: - オーバーレイ（追従と表示制御）

final class Overlay {
    let window: NSWindow
    let view: MangaView
    let tracker = MotionTracker()
    let logger = ResearchLogger()
    let sensor = ContextSensor()
    let keys = KeySensor()
    let touch = TouchSensor()
    let clicks = ClickSensor()
    let edges = EdgeSensor()
    let reject = RejectSensor()
    let caret = CaretSensor()

    // 文字の中心をカーソルのこの高さ（px）上に置く
    let cursorGap: CGFloat = 30

    var currentWord = ""
    var holdUntil: CFTimeInterval = 0
    var displayIntensity: CGFloat = 0.6
    // 生成モード: 動作θからOnomaFormerがその場で新語を生成して表示（行為の変容）
    var generativeMode = UserDefaults.standard.bool(forKey: "generativeMode")
    private var genCache: [String: String] = [:]   // θバケット→生成語
    private var genRNG = SystemRandomNumberGenerator()
    private var genBusy = false
    // 静止時の生物的アイドル語
    private var nextIdleWordAt: CFTimeInterval = 0
    private var frontApp = ""
    private var lastAppCheck: CFTimeInterval = -10

    private func featSnapshot(_ f: MotionFeatures) -> [String: Double] {
        func r2(_ v: CGFloat) -> Double { (Double(v) * 100).rounded() / 100 }
        return ["speed": r2(f.speed), "jerk": r2(f.jerk),
                "turn": r2(f.cumTurn), "straight": r2(f.straight)]
    }
    private var idleWordUntil: CFTimeInterval = -10
    // スティグマ配慮: 不随意状態を名指す語（プルプル/オロオロ/ドキドキ）を表示しない
    var suppressStateWords = UserDefaults.standard.bool(forKey: "suppressStateWords")   // 文字サイズに反映する強度（滑らかに追従）

    init() {
        view = MangaView(frame: NSRect(x: 0, y: 0, width: 820, height: 260))
        window = NSWindow(
            contentRect: view.frame,
            styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .screenSaver
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.contentView = view
        window.alphaValue = 0
        window.orderFrontRegardless()
    }

    // 違和感フィードバック用: 直近に出した語とその瞬間の特徴量
    private var lastShownWord = ""
    private var lastShownAt: CFTimeInterval = -10
    private var lastShownFeatures: [String: Double] = [:]
    var lastTheta: [Double] = [0, 0, 0, 0]
    private var lastChannel = "cursor"

    // 生成語（辞書外・任意文字列）のスタイルをθ→StyleParamsで合成する（Track B）
    static func generatedStyle(_ text: String, theta: [Double]) -> WordStyle {
        let sp = StyleParams.from(theta: theta)
        let g = theta.count > 1 ? theta[1] : 0.5
        let e = theta.count > 2 ? theta[2] : 0
        let r = theta.count > 3 ? theta[3] : 0
        let v = theta.count > 0 ? theta[0] : 0.5
        let color = NSColor(hue: CGFloat(sp.hue), saturation: CGFloat(sp.saturation),
                            brightness: CGFloat(sp.brightness), alpha: 1)
        let anim: Anim = g > 0.7 ? .pita : (r > 0.6 ? .kacha : (e > 0.5 ? .suu : (v > 0.6 ? .bun : .jiwa)))
        return WordStyle(text: text, fontNames: sp.fontHeavy ? GOTHIC : MINCHO,
                         size: CGFloat(28 * sp.sizeScale), color: color, anim: anim,
                         outline: CGFloat(sp.outlineWidth), gradient: CGFloat(sp.gradient),
                         halo: CGFloat(sp.halo), pressure: CGFloat(sp.pressure),
                         taper: CGFloat(sp.taper), roughness: CGFloat(sp.roughness))
    }

    // チャネル/文脈 → 意味カテゴリ（impact/motion/texture/emotion/light/wetdry）
    private func meaningCats() -> [Double] {
        var c = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        switch lastChannel {
        case "keyboard": c[0] = 1   // 打鍵=impact
        case "drag":     c[1] = 1   // ドラッグ=motion
        default:         c[1] = 0.6 // カーソル運動=motion寄り
        }
        if let pc = pendingCat, pc < c.count { c[pc] = 1 }
        // 背景モードのUI要素で意味を足す
        switch sensor.role {
        case "AXStaticText", "AXTextArea", "AXWebArea": c[3] = 0.6  // テキスト上=emotion(読/思)寄り
        case "AXImage": c[4] = 0.6                                  // 画像=light寄り
        case "AXButton", "AXLink": c[0] = max(c[0], 0.6)           // ボタン=impact
        default: break
        }
        return c
    }

    // イベント語を生成モードで新語に着せ替える（打鍵・クリック等も動きから変容）
    // family指定時は族アンカー生成: 音源が明確なイベントは族（カタカタ系/ターン系…）を
    // 守り、揺らぎは族の中に限定する（無制約生成だと打鍵に無関係な語が出てズレる）
    private func maybeGen(_ base: String, extraCat: Int? = nil, family: String? = nil) -> String {
        guard generativeMode, OnomaFormerCore.shared.isReady else { return base }
        if let ec = extraCat { pendingCat = ec }
        return generatedWord(theta: lastTheta, family: family) ?? base
    }
    private var pendingCat: Int?

    // θを粗いバケットにして生成語をキャッシュ（安定性）。時々作り直して変容の新鮮さを出す
    private func generatedWord(theta: [Double], family: String? = nil) -> String? {
        let cats = meaningCats()
        let catKey = cats.map { $0 > 0.5 ? "1" : "0" }.joined()
        let bucket = (family.map { $0 + "|" } ?? "")
            + theta.map { Int(($0 * 4).rounded()) }.map(String.init).joined(separator: "-") + "|" + catKey
        if let cached = genCache[bucket], Int.random(in: 0..<5) != 0 {
            return cached   // 8割キャッシュ・2割は下で作り直し（変容）
        }
        if !genBusy {
            genBusy = true
            let th = theta
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }
                var rng = SystemRandomNumberGenerator()
                let w: String?
                if let family {
                    w = FamilyGen.generate(family: family, theta: th, cats: cats, rng: &rng)
                } else {
                    w = OnomaFormerCore.shared.generate(theta: th, cats: cats, temperature: 1.0, rng: &rng)
                }
                DispatchQueue.main.async {
                    if let w { self.genCache[bucket] = w }
                    if self.genCache.count > 96 { self.genCache.removeAll() }
                    self.genBusy = false
                }
            }
        }
        return genCache[bucket]
    }

    func show(_ key: String, hold: CFTimeInterval, now: CFTimeInterval) {
        if suppressStateWords && stateNamingWords.contains(key) { return }
        guard key != currentWord else { return }
        let style = STYLES[key] ?? DeliveredVocab.shared.style(for: key)
            ?? Self.generatedStyle(key, theta: lastTheta)   // 生成語は任意文字列なのでθから合成
        currentWord = key
        view.setWord(style)
        holdUntil = now + hold
        if key != "チガウチガウ" {
            lastShownWord = key
            lastShownAt = now
            Zukan.shared.record(key)
            // 増幅計測開始: この語が出た瞬間の行為強度を pre として記録
            AmplificationLog.shared.onWord(key, theta: lastTheta, channel: lastChannel,
                                           intensity: Double(displayIntensity))
        }
    }

    func tick() {
        let p = NSEvent.mouseLocation
        let now = CACurrentMediaTime()
        let f = tracker.update(position: p, at: now)
        if f.teleported { return }
        view.dirX = f.dirX

        // 背景モード: カーソル下の要素を取得（5Hz）
        sensor.poll(at: p, now: now)

        var events: [String] = []   // このフレームで発火したイベント（デバッグログ用）

        // 強度（0..1）: 速度 / 打鍵レート / スクロール勢いの最大値に滑らかに追従
        var target = min(1, f.speed / 32)
        if keys.enabled && now - keys.lastKeyTime < 1.0 {
            target = max(target, min(1, keys.typingRate / 9))
        }
        if touch.enabled && now - touch.lastScrollTime < 0.5 {
            target = max(target, min(1, touch.scrollRate / 40))
        }
        displayIntensity = displayIntensity * 0.88 + target * 0.12
        view.intensity = displayIntensity

        // ピタッ!! — 急停止イベント（即時発火。直前の勢いを衝撃の大きさに引き継ぐ）
        if f.pita && currentWord != "ピタッ!!" {
            show("ピタッ!!", hold: 0.9, now: now)
            window.alphaValue = 1
            displayIntensity = max(displayIntensity, 0.85)
            view.intensity = displayIntensity
            events.append("pita")
        }

        // 動き出しイベント — EMA収束を待たず瞬時速度で暫定語を即表示（約35msで応答）。
        // holdを短くして、分類器の確定語（キョロキョロ等）がすぐ上書きできるようにする
        if f.onset {
            show(f.rawD > 22 ? "ビューン" : "スーッ", hold: 0.30, now: now)
            window.alphaValue = 1
            events.append("onset")
        }

        // キーボードモード — Return/Enterでッターン！、打鍵中はカチャカチャ
        var keyActive = false
        if keys.enabled {
            if keys.pendingReturn {
                keys.pendingReturn = false
                currentWord = ""   // 連打でも毎回衝撃演出を出し直す
                // Enterの「強さ」=直前の打鍵速度で語形が揺らぐ（たん→ターン！→ッターン！→ッッターン！！）
                let ew0 = OnomatopeMorphology.enterWord(typingRate: keys.typingRate)
                // Enter=鋭い衝撃。そっと単発で打ったときは余韻（長音）→「かーん」系
                let soft = keys.typingRate < 1.5
                lastTheta = [min(Double(keys.typingRate)/9, 1), soft ? 0.5 : 0.85, soft ? 0.6 : 0, 0]
                let ew = maybeGen(ew0, extraCat: 0, family: "enter")
                show(ew, hold: 0.9, now: now)
                window.alphaValue = 1
                displayIntensity = max(0.6, min(1, keys.typingRate / 8))
                view.intensity = displayIntensity
                events.append("tturn")
                PairQuiz.shared.maybeAsk(word: ew, features: ["typingRate": (Double(keys.typingRate) * 100).rounded() / 100])
            } else if now - keys.lastKeyTime < 0.6, STYLES[currentWord]?.anim != .tturn {
                // タイピングの速さで語形が揺らぐ（ポチポチ→カチャカチャ→カタカタカタ→ダダダダッ）
                let tw0 = OnomatopeMorphology.typingWord(rate: keys.typingRate)
                lastTheta = [min(Double(keys.typingRate)/12, 1), 0.4, 0, 1]  // タイピング=反復
                let tw = maybeGen(tw0, extraCat: 0, family: "typing")
                if currentWord != tw {
                    show(tw, hold: 0.2, now: now)
                    events.append("kacha")
                }
                window.alphaValue = min(1, window.alphaValue + 0.2)
            }
            keyActive = now - keys.lastKeyTime < 1.0
        }

        // 動作の質をセンサーに注入（イベントハンドラが語形生成に使う）
        clicks.currentSpeed = f.speed
        clicks.currentIdle = f.idleSec

        // 長押し: 押し込み続けたらグッ（一度だけ）
        if clicks.enabled && clicks.isDown && !clicks.dragging && !clicks.heldLongFired
            && clicks.pressDuration > 0.35 {
            clicks.heldLongFired = true
            currentWord = ""
            show("グッ", hold: 0.6, now: now)
            window.alphaValue = 1
            events.append("hold")
        }

        // 違和感フィードバック — 右クリック2連打=「違う」（語の表示中〜3秒以内のみ発動）
        if reject.pendingReject {
            reject.pendingReject = false
            clicks.pendingWord = nil   // 2回目のミギクリッ！は取り消し
            clicks.pendingFamily = nil
            if !lastShownWord.isEmpty && (now - lastShownAt < 3.0 || !currentWord.isEmpty) {
                func r2(_ v: CGFloat) -> Double { (Double(v) * 100).rounded() / 100 }
                let fb: [String: Any] = [
                    "ts": Date().timeIntervalSince1970,
                    "type": "reject",
                    "word": lastShownWord,
                    "lang": VocabularyStore.shared.currentLang,
                    "speed": r2(f.speed), "jerk": r2(f.jerk),
                    "turn": r2(f.cumTurn), "straight": r2(f.straight),
                ]
                FeedbackLog.append(fb)
                Uploader.shared.enqueueEvent(type: "reject", payload: fb)
                DeliveredVocab.addPoints(3)
                currentWord = ""
                show("チガウチガウ", hold: 0.9, now: now)
                window.alphaValue = 1
                events.append("reject")
                lastShownWord = ""
            }
        }

        // クリックモード — 語形は動作の質から生成（イベント即時）
        if let cw0 = clicks.pendingWord {
            clicks.pendingWord = nil
            let cfam = clicks.pendingFamily
            clicks.pendingFamily = nil
            let cw = cfam != nil ? maybeGen(cw0, family: cfam) : cw0
            if currentWord != "ッターン！" {
                currentWord = ""   // 連打でも毎回出し直す
                show(cw, hold: 0.55, now: now)
                window.alphaValue = 1
                events.append("click")
                PairQuiz.shared.maybeAsk(word: cw, features: featSnapshot(f))
            }
        }

        // ドラッグ — つかんで動かす（クリックモードと同じセンサー）
        if clicks.enabled && clicks.dragging && currentWord != "ッターン！" {
            let dw: String? = f.speed > 6 ? "グイグイ" : (f.speed > 0.4 ? "ズルズル" : nil)
            if let dw {
                if currentWord != dw {
                    show(dw, hold: 0.3, now: now)
                    events.append("drag")
                } else {
                    holdUntil = now + 0.25   // ドラッグ中は運動語に奪われない
                }
                window.alphaValue = min(1, window.alphaValue + 0.2)
            }
        }

        // ウィンドウ段差 — 窓の縁をまたぐとカタッ（連続でガタガタッ）
        if clicks.enabled, let ew = edges.check(cocoaPoint: p, speed: f.speed, now: now),
           currentWord != "ッターン！" {
            currentWord = ""
            show(maybeGen(ew, family: "edge"), hold: 0.45, now: now)
            window.alphaValue = 1
            events.append("edge")
            PairQuiz.shared.maybeAsk(word: ew, features: featSnapshot(f))
        }

        // トラックパッドモード — スクロール（スルスル/ガーッ）・ピンチ（ガバーッ/キュッ）
        if let tw = touch.touchWord(now: now), currentWord != "ッターン！" {
            if currentWord != tw {
                show(tw, hold: 0.25, now: now)
                events.append("touch")
            }
            window.alphaValue = min(1, window.alphaValue + 0.2)
        }

        // 静止時の生物的な気配: 5秒静止後、9〜16秒おきにそっと呼吸系の語が浮かぶ
        if f.idleSec > 5 && !(keys.enabled && now - keys.lastKeyTime < 2) {
            if nextIdleWordAt == 0 {
                nextIdleWordAt = now + 3 + now.truncatingRemainder(dividingBy: 5)
            }
            if now >= nextIdleWordAt {
                var candidates = suppressStateWords
                    ? ["すぅすぅ", "じわじわ", "ウトウト", "ぼー…"]
                    : ["すぅすぅ", "じわじわ", "そわそわ", "もじもじ", "ウトウト", "ぼー…", "ムズムズ", "ビクビクッ"]
                candidates += DeliveredVocab.shared.unlockedIdleWords(suppressState: suppressStateWords)
                let wd = candidates[Int(now / 7) % candidates.count]
                currentWord = ""
                if wd == "ビクビクッ" {
                    // 静寂の中の不意打ちは目立ってよい
                    show(wd, hold: 0.9, now: now)
                    window.alphaValue = 1.0
                    displayIntensity = 0.6
                    view.intensity = 0.6
                } else {
                    show(wd, hold: 2.2, now: now)
                    window.alphaValue = 0.85
                    displayIntensity = 0.35   // 小さくひそやかに
                    view.intensity = 0.35
                }
                idleWordUntil = now + 2.4
                nextIdleWordAt = now + 9 + (now * 1.3).truncatingRemainder(dividingBy: 7)
                events.append("idle")
            }
        } else {
            nextIdleWordAt = 0
        }

        if f.idleSec > 1.3 && now >= idleWordUntil {
            window.alphaValue = max(0, window.alphaValue - 0.04)
            if window.alphaValue == 0 && !currentWord.isEmpty {
                currentWord = ""
                view.clearWord()
            }
        } else if f.speed > 0.25 || !currentWord.isEmpty {
            window.alphaValue = min(1, window.alphaValue + 0.12)
            if now >= holdUntil {
                var w = classifyMotion(f)
                // 文脈語は「低速で見ている/迷っている」動きの語だけを上書きする
                if let cw = sensor.contextWord(speed: f.speed),
                   w == nil || w == "ソロソロ" || w == "ジリジリ" {
                    w = cw
                }
                if var w {
                    // 生成モード: 動作θからOnomaFormerの新語に着せ替える（同じ動きが毎回新鮮に）
                    if generativeMode, OnomaFormerCore.shared.isReady,
                       let gen = generatedWord(theta: lastTheta) {
                        w = gen
                    }
                    // 速い動きほど語を長く保持する（2026-07-29 第二著者フィードバック:
                    // 「切替が速すぎる・高速時に読めない」— 視線が追従に使われる分、読む時間を確保。
                    // Eq.(comfort)のSwitchペナルティを強度でスケールする実装）
                    show(w, hold: 0.5 + 0.35 * CFTimeInterval(displayIntensity), now: now)
                }
            }
        }

        // 研究ログ（有効時のみ。静止3秒以降は間引くが、打鍵中はキーボード語のため記録継続）
        if logger.enabled && (f.idleSec < 3 || keyActive || touch.active || !events.isEmpty) {
            func r2(_ v: CGFloat) -> Double { (Double(v) * 100).rounded() / 100 }
            var rec: [String: Any] = [
                "ts": Date().timeIntervalSince1970,
                "x": r2(p.x), "y": r2(p.y),
                "d": r2(f.rawD),
                "speed": r2(f.speed), "jerk": r2(f.jerk),
                "fx": f.flipX, "fy": f.flipY,
                "turn": r2(f.cumTurn), "straight": r2(f.straight), "path": r2(f.pathLen),
                "word": currentWord,
            ]
            if sensor.enabled { rec["ctx"] = sensor.role }
            if !events.isEmpty { rec["evt"] = events.joined(separator: ",") }
            // 「どういう時にどの語が出たか」の文脈: 最前面アプリのbundle IDのみ（1秒キャッシュ・内容は見ない）
            if now - lastAppCheck > 1.0 {
                frontApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
                lastAppCheck = now
            }
            if !frontApp.isEmpty { rec["app"] = frontApp }
            logger.log(rec)
        }

        // 増幅計測: 現在の行為強度を流す（語の直後0.8秒で行為が強まったか＝暗黙の報酬）
        lastTheta = MotionToTheta.theta(from: f)
        lastChannel = keys.enabled && now - keys.lastKeyTime < 1.0 ? "keyboard"
            : (clicks.dragging ? "drag" : "cursor")
        AmplificationLog.shared.tick(intensity: Double(displayIntensity))

        // 召喚チャレンジ: 現在語と動作を流す（成功判定＋接地記録はゲーム側）
        if SummonGame.shared.isActive {
            SummonGame.shared.update(currentWord: currentWord, features: featSnapshot(f),
                                     theta: MotionToTheta.theta(from: f))
        }

        // 潜在空間HUD: 現在の動作をθに写して流す
        if LatentHUD.shared.isOpen {
            LatentHUD.shared.update(theta: MotionToTheta.theta(from: f), word: currentWord,
                                    features: featSnapshot(f))
        }
        // 接地ログ: 表示語と動作のペアを教師データ化（研究ログON時のみ・レート制限）
        if logger.enabled && !currentWord.isEmpty {
            GroundingLog.recordShown(word: currentWord, features: featSnapshot(f))
        }

        // 非表示アイドル時は再描画・移動をスキップ（省電力）
        guard window.alphaValue > 0 || !currentWord.isEmpty else { return }
        let size = window.frame.size
        // 打鍵中は「打っている場所」= キャレットの近くに出す
        // （マウスは無関係な場所に置き去りのことが多く、そこに出すと変な空間に飛ぶ）
        var anchor = p
        if keyActive, let cp = caret.anchor(now: now, mouse: p) { anchor = cp }
        window.setFrameOrigin(NSPoint(
            x: anchor.x - size.width / 2,
            y: anchor.y + cursorGap - size.height / 2))
        view.needsDisplay = true
    }
}

// MARK: - メニューバー常駐

final class AppController: NSObject {
    let overlay = Overlay()
    var statusItem: NSStatusItem!
    var pauseItem: NSMenuItem!
    var logItem: NSMenuItem!
    var ctxItem: NSMenuItem!
    var keyItem: NSMenuItem!
    var touchItem: NSMenuItem!
    var clickItem: NSMenuItem!
    var stateItem: NSMenuItem!
    var fxItem: NSMenuItem!
    var legibleItem: NSMenuItem!
    var updateItem: NSMenuItem!
    var uploadItem: NSMenuItem!
    var expItem: NSMenuItem!
    var quizItem: NSMenuItem!
    var genItem: NSMenuItem!
    var langMenu: NSMenu!
    var paused = false
    var timer: Timer?

    // メニューバーアイコン: 固定幅のテンプレート画像（絵文字より省スペースで、混雑時に隠されにくい）
    static func makeIcon(recording: Bool, dimmed: Bool) -> NSImage {
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let attr = NSAttributedString(string: "オ", attributes: [
                .font: NSFont.systemFont(ofSize: 14, weight: .heavy),
                .foregroundColor: NSColor.black.withAlphaComponent(dimmed ? 0.35 : 1.0),
            ])
            let sz = attr.size()
            attr.draw(at: NSPoint(x: (18 - sz.width) / 2, y: (18 - sz.height) / 2))
            if recording {
                NSColor.black.setFill()
                NSBezierPath(ovalIn: NSRect(x: 13, y: 12.5, width: 4.5, height: 4.5)).fill()
            }
            return true
        }
        img.isTemplate = true   // ライト/ダークメニューバーに自動追従
        return img
    }

    func start() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon()

        let menu = NSMenu()
        let title = NSMenuItem(title: "OnomatopeCursor v\(APP_VERSION)", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        let aboutItem = NSMenuItem(title: "このアプリについて（研究プロジェクト）…", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        // 新版があるときだけ表示される行（UpdateCheckerのフックで挿入）
        updateItem = NSMenuItem(title: "", action: #selector(openUpdate), keyEquivalent: "")
        updateItem.target = self
        updateItem.isHidden = true
        menu.addItem(updateItem)
        menu.addItem(.separator())
        // ── コンパクトなトップレベル（日常操作のみ）。他はサブメニューへ ──
        pauseItem = NSMenuItem(title: "一時停止", action: #selector(togglePause), keyEquivalent: "p")
        pauseItem.target = self
        menu.addItem(pauseItem)
        genItem = NSMenuItem(title: "生成モード（動きから新語）", action: #selector(toggleGen), keyEquivalent: "g")
        genItem.target = self
        genItem.state = overlay.generativeMode ? .on : .off
        menu.addItem(genItem)
        // 言語サブメニュー
        let langMenu = NSMenu()
        let langNames = ["ja": "日本語", "en": "English", "zh": "中文", "ko": "한국어", "fr": "Français"]
        for lang in VocabularyStore.shared.availableLangs {
            let item = NSMenuItem(title: langNames[lang] ?? lang, action: #selector(selectLang(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = lang
            item.state = VocabularyStore.shared.currentLang == lang ? .on : .off
            langMenu.addItem(item)
        }
        let langRoot = NSMenuItem(title: "言語 / Language", action: nil, keyEquivalent: "")
        menu.setSubmenu(langMenu, for: langRoot)
        menu.addItem(langRoot)
        self.langMenu = langMenu
        menu.addItem(.separator())

        // 入力チャネル
        let chMenu = NSMenu()
        ctxItem = NSMenuItem(title: "背景モード（実験的）", action: #selector(toggleContext), keyEquivalent: "b")
        ctxItem.target = self
        keyItem = NSMenuItem(title: "キーボードモード（実験的）", action: #selector(toggleKeys), keyEquivalent: "k")
        keyItem.target = self
        #if !APPSTORE
        // App Store版はサンドボックス/審査ポリシー(Accessibility不可)のため
        // 背景モード・キーボードモードを出さない（docs/APPSTORE.md）
        chMenu.addItem(ctxItem)
        chMenu.addItem(keyItem)
        #endif
        touchItem = NSMenuItem(title: "トラックパッドモード（実験的）", action: #selector(toggleTouch), keyEquivalent: "t")
        touchItem.target = self
        chMenu.addItem(touchItem)
        clickItem = NSMenuItem(title: "物理モード（クリック・ドラッグ・段差）", action: #selector(toggleClicks), keyEquivalent: "c")
        clickItem.target = self
        chMenu.addItem(clickItem)
        let chRoot = NSMenuItem(title: "入力チャネル", action: nil, keyEquivalent: "")
        menu.setSubmenu(chMenu, for: chRoot)
        menu.addItem(chRoot)

        // 表示
        let dispMenu = NSMenu()
        fxItem = NSMenuItem(title: "コミックエフェクト", action: #selector(toggleFX), keyEquivalent: "e")
        fxItem.target = self
        fxItem.state = MangaView.comicFX ? .on : .off
        dispMenu.addItem(fxItem)
        legibleItem = NSMenuItem(title: "高視認スタイル（白文字＋影）", action: #selector(toggleLegible), keyEquivalent: "")
        legibleItem.target = self
        legibleItem.state = MangaView.legibleMode ? .on : .off
        dispMenu.addItem(legibleItem)
        stateItem = NSMenuItem(title: "状態語を表示しない（プルプル等）", action: #selector(toggleStateWords), keyEquivalent: "")
        stateItem.target = self
        stateItem.state = overlay.suppressStateWords ? .on : .off
        dispMenu.addItem(stateItem)
        let dispRoot = NSMenuItem(title: "表示", action: nil, keyEquivalent: "")
        menu.setSubmenu(dispMenu, for: dispRoot)
        menu.addItem(dispRoot)

        // あそぶ
        let playMenu = NSMenu()
        let zukanItem = NSMenuItem(title: "オノマトペ図鑑…", action: #selector(showZukan), keyEquivalent: "z")
        zukanItem.target = self
        playMenu.addItem(zukanItem)
        let hudItem = NSMenuItem(title: "潜在空間HUD（新語を探す）…", action: #selector(toggleHUD), keyEquivalent: "h")
        hudItem.target = self
        playMenu.addItem(hudItem)
        let summonItem = NSMenuItem(title: "召喚チャレンジ（お題の語を動きで出す）", action: #selector(startSummon), keyEquivalent: "")
        summonItem.target = self
        playMenu.addItem(summonItem)
        quizItem = NSMenuItem(title: "2択クイズ（どっちが自然？）", action: #selector(toggleQuiz), keyEquivalent: "q")
        quizItem.target = self
        quizItem.state = PairQuiz.shared.enabled ? .on : .off
        playMenu.addItem(quizItem)
        let playRoot = NSMenuItem(title: "あそぶ", action: nil, keyEquivalent: "")
        menu.setSubmenu(playMenu, for: playRoot)
        menu.addItem(playRoot)

        // 研究モード（すべて丁寧なオプトインの向こう側）
        let resMenu = NSMenu()
        logItem = NSMenuItem(title: "研究ログを記録", action: #selector(toggleLog), keyEquivalent: "l")
        logItem.target = self
        resMenu.addItem(logItem)
        uploadItem = NSMenuItem(title: "データ提供に協力（実験用）", action: #selector(toggleUpload), keyEquivalent: "")
        uploadItem.target = self
        uploadItem.state = Uploader.shared.consent ? .on : .off
        resMenu.addItem(uploadItem)
        expItem = NSMenuItem(title: "被験者実験セッション…", action: #selector(toggleExperiment), keyEquivalent: "")
        expItem.target = self
        resMenu.addItem(expItem)
        resMenu.addItem(.separator())
        let openLogs = NSMenuItem(title: "ログフォルダを開く", action: #selector(openLogFolder), keyEquivalent: "")
        openLogs.target = self
        resMenu.addItem(openLogs)
        let resRoot = NSMenuItem(title: "研究モード", action: nil, keyEquivalent: "")
        menu.setSubmenu(resMenu, for: resRoot)
        menu.addItem(resRoot)

        menu.addItem(.separator())
        let fbItem = NSMenuItem(title: "フィードバック・リクエストを送る…", action: #selector(openFeedback), keyEquivalent: "")
        fbItem.target = self
        menu.addItem(fbItem)
        let surveyItem = NSMenuItem(title: "アンケートに答える（1分・+5pt）…", action: #selector(openSurvey), keyEquivalent: "")
        surveyItem.target = self
        menu.addItem(surveyItem)
        #if !APPSTORE   // Store版の更新はApp Storeが担う。appcastは使わない
        let updCheck = NSMenuItem(title: "アップデートを確認…", action: #selector(checkUpdates), keyEquivalent: "")
        updCheck.target = self
        menu.addItem(updCheck)
        #endif
        let quit = NSMenuItem(title: "終了", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu

        // 前回ONだった入力チャネルを復元（2026-07-31: 再起動でカタカタが消える問題の修正）。
        // AX系（キーボード/トラックパッド/背景）は許可済みのときだけ静かに復元し、
        // 未許可なら起動時にプロンプトを出さない（次に手動でONにした時に出る）
        if UserDefaults.standard.bool(forKey: "clickMode"), overlay.clicks.enable() {
            clickItem.state = .on
        }
        #if APPSTORE
        if UserDefaults.standard.bool(forKey: "touchMode"), overlay.touch.enable() {
            touchItem.state = .on
        }
        #else
        if AXIsProcessTrusted() {
            if UserDefaults.standard.bool(forKey: "keyboardMode"), overlay.keys.enable() {
                keyItem.state = .on
            }
            if UserDefaults.standard.bool(forKey: "touchMode"), overlay.touch.enable() {
                touchItem.state = .on
            }
            if UserDefaults.standard.bool(forKey: "contextMode"), overlay.sensor.enable() {
                ctxItem.state = .on
            }
        }
        #endif

        overlay.reject.start()   // 右クリック2連打=「違う」（常時・権限不要）

        // データ提供キューの送信＋語彙フィード受信（起動時＋5分ごと。同意OFF時は何もしない）
        DeliveredVocab.shared.loadCache()
        Uploader.shared.flush()
        DeliveredVocab.shared.fetch()
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Uploader.shared.flush()
            DeliveredVocab.shared.fetch()
            #if !APPSTORE
            UpdateChecker.shared.autoCheck()
            #endif
        }

        // セキュア入力の可視化（2026-07-31デバッグの教訓）: パスワード欄等が
        // Secure Inputを掴んでいる間、キー監視はOSにより全面遮断される。
        // 無言で死なせず、メニューに停止理由を表示する
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self, self.overlay.keys.enabled else { return }
            let blocked = IsSecureEventInputEnabled()
            let base = "キーボードモード（実験的）"
            let want = blocked ? base + " ⚠️セキュア入力により停止中" : base
            if self.keyItem.title != want { self.keyItem.title = want }
        }

        #if !APPSTORE
        // アップデート通知（自動確認は同意ON時のみ・24hに1回。手動確認は常時可）
        UpdateChecker.shared.onAvailable = { [weak self] info in
            guard let self else { return }
            self.updateItem.title = "⤓ v\(info.version) が利用可能（ダウンロード）…"
            self.updateItem.isHidden = false
        }
        UpdateChecker.shared.autoCheck()
        #endif

        // 初回起動: 研究プロジェクトであることの明示（1回だけ・短く）
        if !UserDefaults.standard.bool(forKey: "shownWelcome") {
            UserDefaults.standard.set(true, forKey: "shownWelcome")
            let a = NSAlert()
            a.messageText = "OnomatopeCursor へようこそ 👀"
            a.informativeText = """
            カーソルの動きをオノマトペで実況するアプリです。

            これは筑波大学 デジタルネイチャー研究室の研究プロジェクトです（Yoichi Ochiai / Miki Okamura）。
            ・そのまま使う分には、ネットワーク通信も記録も一切ありません
            ・メニュー「研究モード」から匿名データ提供・研究ログをオプトインできます（内容は都度明示・いつでもOFF）
            ・詳細は「このアプリについて」または配布フォルダの「はじめにお読みください」へ
            """
            a.addButton(withTitle: "はじめる")
            a.runModal()
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self, !self.paused else { return }
            self.overlay.tick()
        }
        // メニュー表示中（イベントトラッキング中）も追従を続ける
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    func updateIcon() {
        statusItem.button?.title = ""
        statusItem.button?.image = Self.makeIcon(recording: overlay.logger.enabled, dimmed: paused)
    }

    @objc func togglePause() {
        paused.toggle()
        pauseItem.title = paused ? "再開" : "一時停止"
        if paused {
            overlay.window.alphaValue = 0
            overlay.currentWord = ""
            overlay.view.clearWord()
            overlay.logger.flush()
        } else {
            overlay.tracker.resetPosition(NSEvent.mouseLocation)   // 再開時のスパイク防止
        }
        updateIcon()
    }

    @objc func toggleContext() {
        if overlay.sensor.enabled {
            overlay.sensor.disable()
        } else if !overlay.sensor.enable() {
            // 未許可: システムのプロンプトが出るので、許可後にもう一度選んでもらう
            ctxItem.state = .off
            return
        }
        ctxItem.state = overlay.sensor.enabled ? .on : .off
        UserDefaults.standard.set(overlay.sensor.enabled, forKey: "contextMode")
    }

    @objc func toggleKeys() {
        if overlay.keys.enabled {
            overlay.keys.disable()
        } else if !overlay.keys.enable() {
            keyItem.state = .off
            return
        }
        keyItem.state = overlay.keys.enabled ? .on : .off
        UserDefaults.standard.set(overlay.keys.enabled, forKey: "keyboardMode")
    }

    @objc func toggleTouch() {
        if overlay.touch.enabled {
            overlay.touch.disable()
        } else if !overlay.touch.enable() {
            touchItem.state = .off
            return
        }
        touchItem.state = overlay.touch.enabled ? .on : .off
        UserDefaults.standard.set(overlay.touch.enabled, forKey: "touchMode")
    }

    @objc func selectLang(_ sender: NSMenuItem) {
        guard let lang = sender.representedObject as? String else { return }
        VocabularyStore.shared.currentLang = lang
        UserDefaults.standard.set(lang, forKey: "language")
        for item in langMenu.items {
            item.state = (item.representedObject as? String) == lang ? .on : .off
        }
        overlay.currentWord = ""   // 次の語から新言語で
        overlay.view.clearWord()
    }

    @objc func toggleQuiz() {
        PairQuiz.shared.enabled.toggle()
        quizItem.state = PairQuiz.shared.enabled ? .on : .off
    }

    @objc func showZukan() {
        Zukan.shared.showWindow()
    }

    @objc func toggleHUD() {
        LatentHUD.shared.toggle()
    }

    @objc func toggleGen() {
        overlay.generativeMode.toggle()
        UserDefaults.standard.set(overlay.generativeMode, forKey: "generativeMode")
        genItem.state = overlay.generativeMode ? .on : .off
    }

    @objc func startSummon() {
        SummonGame.shared.start()
    }

    @objc func toggleUpload() {
        if !Uploader.shared.consent {
            // ON時は毎回、送信先と送信内容を明示して同意を取る（丁寧なオプトイン）
            let alert = NSAlert()
            alert.messageText = "データ提供に協力しますか？"
            var info = "送信先: 研究用データベース（Supabase・書き込み専用・匿名IDのみで氏名とは紐付きません）\n送信されるもの:\n・カーソルの運動特徴量と表示された語（研究ログと同じ内容）\n・「チガウチガウ」の否定フィードバック・2択クイズの回答\n・図鑑の捕獲イベント\n送信されないもの: 画面の内容・キー入力の内容・クリック先・個人情報\nいつでもこのメニューからOFFにできます。"
            if Uploader.shared.config == nil {
                info += "\n\n⚠️ 送信先設定（upload.json）が未配置のため、ONにしてもローカルキューに貯まるだけで送信はされません。"
            }
            alert.informativeText = info
            alert.addButton(withTitle: "協力する")
            alert.addButton(withTitle: "やめておく")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        Uploader.shared.consent.toggle()
        uploadItem.state = Uploader.shared.consent ? .on : .off
    }

    @objc func toggleFX() {
        MangaView.comicFX.toggle()
        UserDefaults.standard.set(MangaView.comicFX, forKey: "comicFX")
        fxItem.state = MangaView.comicFX ? .on : .off
        overlay.currentWord = ""
        overlay.view.clearWord()
    }

    @objc func toggleLegible() {
        MangaView.legibleMode.toggle()
        UserDefaults.standard.set(MangaView.legibleMode, forKey: "legibleMode")
        legibleItem.state = MangaView.legibleMode ? .on : .off
        overlay.currentWord = ""
        overlay.view.clearWord()
    }

    @objc func toggleStateWords() {
        overlay.suppressStateWords.toggle()
        UserDefaults.standard.set(overlay.suppressStateWords, forKey: "suppressStateWords")
        stateItem.state = overlay.suppressStateWords ? .on : .off
    }

    @objc func toggleClicks() {
        if overlay.clicks.enabled {
            overlay.clicks.disable()
        } else {
            _ = overlay.clicks.enable()
        }
        clickItem.state = overlay.clicks.enabled ? .on : .off
        UserDefaults.standard.set(overlay.clicks.enabled, forKey: "clickMode")
    }

    /// 研究ログの丁寧なオプトイン: ON時は毎回、記録内容と保存先を明示して同意を取る
    private func confirmLogStart() -> Bool {
        let alert = NSAlert()
        alert.messageText = "研究ログを記録しますか？"
        alert.informativeText = "このMacのローカルファイル（JSONL・提出前に目視確認できます）にのみ保存されます:\n・カーソル座標(x,y)・速度・ジャーク等の運動特徴量\n・表示された語・発火イベント\n・最前面アプリのbundle IDのみ（背景モードON時はUI要素の種別名も）\n記録しないもの: 画面の内容・キー入力の内容・URL・文言・個人情報\n記録中はメニューバーのアイコンに🔴が付きます。\n「データ提供に協力」がONの場合、記録終了時にログが匿名IDで送信キューに入ります。"
        alert.addButton(withTitle: "記録を開始")
        alert.addButton(withTitle: "キャンセル")
        return alert.runModal() == .alertFirstButtonReturn
    }

    @objc func toggleLog() {
        if overlay.logger.enabled {
            let fileURL = overlay.logger.currentFileURL
            overlay.logger.stop()
            if let fileURL { Uploader.shared.enqueueSessionFile(fileURL) }
        } else {
            guard confirmLogStart() else { return }
            overlay.logger.start(meta: ["app_version": APP_VERSION,
                                        "screen_w": Double(NSScreen.screens.first?.frame.width ?? 0),
                                        "screen_h": Double(NSScreen.screens.first?.frame.height ?? 0)])
        }
        logItem.state = overlay.logger.enabled ? .on : .off
        updateIcon()
    }

    // ── 被験者実験セッション（丁寧な二段オプトイン: 説明→同意→ID入力） ──
    var experimentID: String?

    @objc func toggleExperiment() {
        if let pid = experimentID {
            // セッション終了 → デブリーフィングの促し
            let fileURL = overlay.logger.currentFileURL
            overlay.logger.stop()
            if let fileURL { Uploader.shared.enqueueSessionFile(fileURL) }
            experimentID = nil
            expItem.title = "被験者実験セッション…"
            logItem.state = .off
            updateIcon()
            let done = NSAlert()
            done.messageText = "実験セッション（\(pid)）を終了しました"
            done.informativeText = "ログはローカルに保存されています。ミスマッチ語条件が含まれていた場合は、目的の説明とデータ削除の申し出受付（デブリーフィング）を必ず行ってください。"
            done.addButton(withTitle: "ログフォルダを開く")
            done.addButton(withTitle: "閉じる")
            if done.runModal() == .alertFirstButtonReturn { openLogFolder() }
            return
        }

        // 段1: 説明と同意（docs/ethics/consent-form.md の要点）
        let consent = NSAlert()
        consent.messageText = "被験者実験セッションを開始します"
        consent.informativeText = "この研究は「カーソル運動の言語的ミラーリングが体験と運動に与える影響」を調べます。\n\n・参加は任意で、いつでも中止できます（不利益はありません）\n・記録するもの: カーソル座標・運動特徴量・表示語・条件（画面の内容やキー入力の内容は記録しません）\n・一部の条件では動作と一致しない語が意図的に表示されることがあります（終了後に説明します）\n・データは匿名IDで管理し、学術発表では統計量のみ使用します\n・不快な語が表示された場合は遠慮なくお申し出ください（表示を止められます）\n\n説明文書・同意書の正本: docs/ethics/consent-form.md（書面同意の後に開始してください）"
        consent.addButton(withTitle: "同意を確認した（次へ）")
        consent.addButton(withTitle: "キャンセル")
        guard consent.runModal() == .alertFirstButtonReturn else { return }

        // 段2: 参加者ID入力（実験者が入力）
        let idAlert = NSAlert()
        idAlert.messageText = "参加者IDを入力"
        idAlert.informativeText = "セッション計画（tools/make_session_plan.py）のID（例: P03）"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.placeholderString = "P00"
        idAlert.accessoryView = field
        idAlert.window.initialFirstResponder = field
        idAlert.addButton(withTitle: "セッション開始")
        idAlert.addButton(withTitle: "キャンセル")
        guard idAlert.runModal() == .alertFirstButtonReturn else { return }
        let pid = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !pid.isEmpty else { return }

        experimentID = pid
        overlay.logger.start(meta: ["app_version": APP_VERSION,
                                    "experiment": true,
                                    "participant": pid,
                                    "consent_ts": Date().timeIntervalSince1970,
                                    "screen_w": Double(NSScreen.screens.first?.frame.width ?? 0),
                                    "screen_h": Double(NSScreen.screens.first?.frame.height ?? 0)])
        expItem.title = "実験セッションを終了（\(pid)）"
        logItem.state = .on
        updateIcon()
    }

    @objc func openFeedback() {
        // 語のズレ報告テンプレート付きのIssues（アプリ内のチガウチガウ=右クリック2連打も有効）
        NSWorkspace.shared.open(URL(string: "https://github.com/ochyai/OnomatopeCursor/issues/new/choose")!)
    }

    // ── アプリ内1分アンケート（回答はローカル保存＋データ提供ON時のみ送信） ──
    @objc func openSurvey() {
        let questions = [
            "使っていて楽しい",
            "語は自分の動きを言い当てている",
            "語に合わせて自分の動きの感じ方が変わることがある",
            "これからも使い続けたい",
        ]
        let alert = NSAlert()
        alert.messageText = "1分アンケート"
        alert.informativeText = "1=まったくそう思わない 〜 7=とてもそう思う"
        let stack = NSStackView(frame: NSRect(x: 0, y: 0, width: 380, height: CGFloat(questions.count * 34 + 66)))
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        var pickers: [NSPopUpButton] = []
        for q in questions {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 6
            let pop = NSPopUpButton(frame: .zero, pullsDown: false)
            pop.addItems(withTitles: ["–", "1", "2", "3", "4", "5", "6", "7"])
            pickers.append(pop)
            let label = NSTextField(labelWithString: q)
            label.font = .systemFont(ofSize: 12)
            row.addArrangedSubview(pop)
            row.addArrangedSubview(label)
            stack.addArrangedSubview(row)
        }
        let free = NSTextField(frame: NSRect(x: 0, y: 0, width: 380, height: 48))
        free.placeholderString = "自由記述（好きな語・気になったこと・ほしい機能など）"
        stack.addArrangedSubview(free)
        free.widthAnchor.constraint(equalToConstant: 380).isActive = true
        free.heightAnchor.constraint(equalToConstant: 48).isActive = true
        alert.accessoryView = stack
        alert.addButton(withTitle: "送信")
        alert.addButton(withTitle: "キャンセル")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        var payload: [String: Any] = ["ts": Date().timeIntervalSince1970,
                                      "type": "survey", "app_version": APP_VERSION,
                                      "lang": VocabularyStore.shared.currentLang,
                                      "generative": overlay.generativeMode]
        for (i, pop) in pickers.enumerated() {
            if pop.indexOfSelectedItem > 0 { payload["q\(i + 1)"] = pop.indexOfSelectedItem }
        }
        let text = free.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { payload["text"] = text }
        FeedbackLog.append(payload)                                  // ローカルは常に
        Uploader.shared.enqueueEvent(type: "survey", payload: payload)  // 送信は同意ON時のみ
        DeliveredVocab.addPoints(5)
        let thanks = NSAlert()
        thanks.messageText = "ありがとうございました！（+5pt）"
        thanks.informativeText = Uploader.shared.consent
            ? "回答は匿名IDで研究サーバーに送信されます。"
            : "回答はローカルに保存されました（「データ提供に協力」ONで研究にも届きます）。"
        thanks.runModal()
    }

    @objc func openLogFolder() {
        try? FileManager.default.createDirectory(at: overlay.logger.dirURL, withIntermediateDirectories: true)
        NSWorkspace.shared.open(overlay.logger.dirURL)
    }

    @objc func quitApp() {
        overlay.logger.stop()
        NSApp.terminate(nil)
    }

    @objc func showAbout() {
        let a = NSAlert()
        a.messageText = "OnomatopeCursor v\(APP_VERSION)"
        a.informativeText = """
        カーソル運動の言語的ミラーリングを研究するHCIプロジェクトです。
        筑波大学 デジタルネイチャー研究室 — Yoichi Ochiai / Miki Okamura

        ・研究への協力（匿名データ提供・研究ログ・実験セッション）はすべてオプトインで、内容は有効化のたびに明示されます
        ・「データ提供に協力」OFF（初期状態）ではネットワーク通信はありません
        ・送信されるのは匿名IDと運動特徴量・表示語・フィードバックのみ（画面内容・キー入力の中身・クリック先は読みません）
        """
        a.addButton(withTitle: "OK")
        a.addButton(withTitle: "GitHubを開く")
        if a.runModal() == .alertSecondButtonReturn {
            NSWorkspace.shared.open(URL(string: "https://github.com/ochyai/OnomatopeCursor")!)
        }
    }

    @objc func checkUpdates() {
        UpdateChecker.shared.check { info in
            let a = NSAlert()
            if let info {
                a.messageText = "新しいバージョン v\(info.version) があります"
                a.informativeText = info.notes.isEmpty ? "現在: v\(APP_VERSION)" : "現在: v\(APP_VERSION)\n\n\(info.notes)"
                a.addButton(withTitle: "ダウンロードページを開く")
                a.addButton(withTitle: "あとで")
                if a.runModal() == .alertFirstButtonReturn {
                    NSWorkspace.shared.open(URL(string: info.url)!)
                }
            } else {
                a.messageText = "お使いのバージョンは最新です"
                a.informativeText = "OnomatopeCursor v\(APP_VERSION)"
                a.addButton(withTitle: "OK")
                a.runModal()
            }
        }
    }

    @objc func openUpdate() {
        if let info = UpdateChecker.shared.available {
            NSWorkspace.shared.open(URL(string: info.url)!)
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// 語彙パックのロード: アプリバンドル Resources/i18n → 実行ファイル隣 → リポジトリ ./i18n の順
for dir in [Bundle.main.resourceURL?.appendingPathComponent("i18n"),
            Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("i18n"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("i18n")] {
    if let dir {
        VocabularyStore.shared.load(from: dir)
        let mf = dir.appendingPathComponent("onomaformer.json")
        if FileManager.default.fileExists(atPath: mf.path), !OnomaFormerCore.shared.isReady {
            OnomaFormerCore.shared.load(from: mf)
        }
        let sm = dir.appendingPathComponent("stylemap.json")
        if FileManager.default.fileExists(atPath: sm.path), !StyleMap.shared.isLoaded {
            StyleMap.shared.load(from: sm)
        }
    }
}
VocabularyStore.shared.currentLang = UserDefaults.standard.string(forKey: "language") ?? "ja"

let controller = AppController()
controller.start()

// exit(0)経由（SIGINT/SIGTERM）でもログをフラッシュする
atexit { controller.overlay.logger.stop() }

signal(SIGINT) { _ in exit(0) }
signal(SIGTERM) { _ in exit(0) }

app.run()

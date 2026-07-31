// 潜在空間HUD — カーソル/キーボードの動作がオノマトペθ空間のどこにいるかを可視化
//
// 促音度(x) × 濁音度(y) の平面に既存語をプロットし、いまの動作のθ点を光点で表示。
// 未命名地帯（どの語からも遠い）に入るとOnomaFormerがその場で新オノマトペを生成し、
// その (動作特徴, θ, 生成語) を接地データとして記録する（学習の教師になる）。
import Cocoa
import OnomatopeCore

final class LatentHUD {
    static let shared = LatentHUD()

    private var window: NSPanel?
    private let view = HUDView()

    var isOpen: Bool { window != nil }

    func toggle() {
        if let w = window { w.close(); window = nil; return }
        let p = NSPanel(contentRect: NSRect(x: 100, y: 100, width: 420, height: 500),
                        styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.title = "オノマトペ潜在空間"
        p.isFloatingPanel = true
        p.level = .floating
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        p.contentView = view
        view.frame = p.contentLayoutRect
        view.autoresizingMask = [.width, .height]
        p.orderFrontRegardless()
        window = p
    }

    func update(theta: [Double], word: String, features: [String: Double]) {
        guard window != nil else { return }
        view.theta = theta
        view.word = word
        view.features = features
        view.needsDisplay = true
    }
}

private final class HUDView: NSView {
    var theta: [Double] = [0, 0, 0, 0]
    var word = ""
    var features: [String: Double] = [:]
    private var trail: [CGPoint] = []
    private var genWord = ""
    private var lastGenAt: CFTimeInterval = 0
    private var rng = SystemRandomNumberGenerator()

    override var isFlipped: Bool { false }

    // 既存語のθ座標（促音x, 濁音y, 色）
    private static let anchors: [(String, Double, Double, NSColor)] = [
        ("ソロソロ", 0.10, 0.10, .systemGreen), ("ポチ", 0.10, 0.05, .systemGray),
        ("カチッ", 0.60, 0.40, .systemBlue), ("バチンッ", 0.95, 0.90, .systemRed),
        ("ビューン", 0.50, 0.50, .systemYellow), ("ドサッ", 0.70, 0.92, .systemBrown),
        ("ピタッ!!", 1.00, 0.50, .systemPink), ("グルグル", 0.12, 0.42, .systemOrange),
        ("ふわふわ", 0.02, 0.03, .systemTeal), ("ガタガタ", 0.55, 0.82, .systemIndigo),
        ("スーッ", 0.08, 0.12, .systemCyan), ("ダダダッ", 0.72, 0.70, .systemPurple),
    ]

    private let pad: CGFloat = 46

    override func draw(_ dirtyRect: NSRect) {
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        let plotBottom: CGFloat = 150   // 下部にゲージ帯を確保
        let plotSize = min(bounds.width - pad * 2, bounds.height - plotBottom - pad)
        let ox = (bounds.width - plotSize) / 2
        let oy = bounds.height - pad - plotSize
        func px(_ x: Double) -> CGFloat { ox + CGFloat(x) * plotSize }
        func py(_ y: Double) -> CGFloat { oy + CGFloat(y) * plotSize }

        NSColor(white: 0.10, alpha: 1).setFill()
        cg.fill(bounds)

        // グリッド
        NSColor(white: 0.20, alpha: 1).setStroke()
        cg.setLineWidth(0.5)
        for i in 1..<5 {
            let t = Double(i) / 5
            cg.strokeLineSegments(between: [CGPoint(x: px(t), y: oy), CGPoint(x: px(t), y: oy + plotSize)])
            cg.strokeLineSegments(between: [CGPoint(x: ox, y: py(t)), CGPoint(x: ox + plotSize, y: py(t))])
        }
        NSColor(white: 0.45, alpha: 1).setStroke(); cg.setLineWidth(1.2)
        cg.stroke(CGRect(x: ox, y: oy, width: plotSize, height: plotSize))
        text("促音度（鋭さ）→", NSPoint(x: ox, y: oy - 20), 11, NSColor(white: 0.7, alpha: 1))
        text("濁音度（重さ）↑", NSPoint(x: ox - 34, y: oy + 4), 11, NSColor(white: 0.7, alpha: 1), rot: 90)

        // 既存語アンカー
        for (w, x, y, c) in Self.anchors {
            c.withAlphaComponent(0.85).setFill()
            cg.fillEllipse(in: CGRect(x: px(x) - 3, y: py(y) - 3, width: 6, height: 6))
            text(w, NSPoint(x: px(x) + 5, y: py(y) - 6), 9.5, c.withAlphaComponent(0.9))
        }

        // θ軌跡
        let cx = px(theta.count > 1 ? theta[1] : 0)
        let cy = py(theta.count > 0 ? theta[0] : 0)
        trail.append(CGPoint(x: cx, y: cy))
        if trail.count > 50 { trail.removeFirst() }
        cg.setLineWidth(2.5); cg.setLineCap(.round)
        for i in 1..<trail.count {
            let a = CGFloat(i) / CGFloat(trail.count)
            NSColor(calibratedHue: 0.52, saturation: 0.8, brightness: 1, alpha: a * 0.6).setStroke()
            cg.strokeLineSegments(between: [trail[i-1], trail[i]])
        }

        // 未命名地帯の判定
        var nearest = 1e9
        for (_, x, y, _) in Self.anchors {
            nearest = min(nearest, Double(hypot(cx - px(x), cy - py(y))))
        }
        let gap = nearest > plotSize * 0.14

        // 現在点（発光）
        let dotColor: NSColor = gap ? .systemPink : .systemCyan
        for (r, a) in [(14.0, 0.25), (9.0, 0.5)] {
            dotColor.withAlphaComponent(a).setFill()
            cg.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r*2, height: r*2))
        }
        dotColor.setFill(); cg.fillEllipse(in: CGRect(x: cx - 5, y: cy - 5, width: 10, height: 10))
        NSColor.white.setStroke(); cg.setLineWidth(1.5)
        cg.strokeEllipse(in: CGRect(x: cx - 5, y: cy - 5, width: 10, height: 10))

        // ── 下部: θゲージ4本 ──
        let gaugeY = oy - 54
        let labels = ["濁 voicing", "促 gemination", "長 elongation", "反 reduplication"]
        let gcols: [NSColor] = [.systemRed, .systemYellow, .systemCyan, .systemPurple]
        for i in 0..<4 {
            let y = gaugeY - CGFloat(i) * 24
            text(labels[i], NSPoint(x: ox, y: y + 2), 10, NSColor(white: 0.65, alpha: 1))
            let barX = ox + 130, barW = plotSize + ox - barX - 30
            NSColor(white: 0.2, alpha: 1).setFill()
            cg.fill(CGRect(x: barX, y: y, width: barW, height: 12))
            let v = CGFloat(i < theta.count ? theta[i] : 0)
            gcols[i].setFill()
            cg.fill(CGRect(x: barX, y: y, width: barW * v, height: 12))
            text(String(format: "%.2f", i < theta.count ? theta[i] : 0),
                 NSPoint(x: barX + barW + 4, y: y + 1), 9, NSColor(white: 0.7, alpha: 1))
        }

        // ── 最上部: 現在の語 or 新語 ──
        if gap {
            NSColor.systemPink.withAlphaComponent(0.85).setStroke()
            cg.setLineWidth(3); cg.stroke(bounds.insetBy(dx: 2, dy: 2))
            let now = CACurrentMediaTime()
            if now - lastGenAt > 1.4, OnomaFormerCore.shared.isReady {
                lastGenAt = now
                if let w = OnomaFormerCore.shared.generate(theta: theta, temperature: 1.0, rng: &rng) {
                    genWord = w
                    // 接地データ: この動作θからの生成語を記録（学習の教師）
                    GroundingLog.record(word: w, theta: theta, source: "hud_gen", features: features)
                }
            }
            text("⚠ 未命名地帯 — 新しい擬態語が生まれる場所", NSPoint(x: 14, y: bounds.height - 26), 12, .systemPink)
            if !genWord.isEmpty {
                text(genWord, NSPoint(x: 14, y: bounds.height - 62), 30, .systemYellow)
                text("この動きにまだ名前がなかった", NSPoint(x: 16, y: bounds.height - 76), 10, NSColor(white: 0.6, alpha: 1))
            }
        } else {
            genWord = ""
            text(word.isEmpty ? "（動かしてみて）" : word, NSPoint(x: 14, y: bounds.height - 40), 22,
                 word.isEmpty ? NSColor(white: 0.5, alpha: 1) : .systemCyan)
        }
    }

    private func text(_ s: String, _ p: NSPoint, _ size: CGFloat, _ color: NSColor, rot: CGFloat = 0) {
        let attr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: .medium), .foregroundColor: color]
        if rot != 0 {
            NSGraphicsContext.current?.saveGraphicsState()
            let t = NSAffineTransform(); t.translateX(by: p.x, yBy: p.y); t.rotate(byDegrees: rot); t.concat()
            (s as NSString).draw(at: .zero, withAttributes: attr)
            NSGraphicsContext.current?.restoreGraphicsState()
        } else {
            (s as NSString).draw(at: p, withAttributes: attr)
        }
    }
}

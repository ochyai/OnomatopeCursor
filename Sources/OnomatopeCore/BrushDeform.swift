// 筆圧・テーパー・かすれ — グリフ輪郭のベクター変形（描き文字の深化）
//
// フォントの均質なアウトラインを「筆で描いた」輪郭に変形する:
//   筆圧: 輪郭点を法線方向に低周波で膨張/収縮（画が太くなったり痩せたりする）
//   テーパー: サブパス（画）の入りと抜きで痩せる（筆の入り・抜き）
//   かすれ: グリフ内を走る細い削り筋（呼び出し側が destinationOut で抜く）
// 決定的（seed）なので、ボイルアニメの変種ごとに揺らげる。
import Foundation
import CoreGraphics

public enum BrushDeform {

    /// グリフ輪郭に筆圧＋テーパーをかけた新しいパスを返す。
    /// pressure/taper は 0..1。fontSize は変形量のスケール基準。
    public static func apply(to path: CGPath, fontSize: CGFloat,
                             pressure: Double, taper: Double, seed: CGFloat) -> CGPath {
        guard pressure > 0.01 || taper > 0.01 else { return path }

        // 1) 要素列を収集（サブパス単位で端点インデックスを振る）
        struct Elem { let type: CGPathElementType; let pts: [CGPoint] }
        var elems: [Elem] = []
        path.applyWithBlock { e in
            let n: Int
            switch e.pointee.type {
            case .moveToPoint, .addLineToPoint: n = 1
            case .addQuadCurveToPoint: n = 2
            case .addCurveToPoint: n = 3
            default: n = 0
            }
            elems.append(Elem(type: e.pointee.type, pts: (0..<n).map { e.pointee.points[$0] }))
        }

        // 2) サブパスごとに端点列と符号付き面積（向き）を求める
        var subpaths: [[Int]] = []      // elems のインデックス列
        var current: [Int] = []
        for (i, el) in elems.enumerated() {
            if el.type == .moveToPoint {
                if !current.isEmpty { subpaths.append(current) }
                current = [i]
            } else {
                current.append(i)
            }
        }
        if !current.isEmpty { subpaths.append(current) }

        func endpoint(_ el: Elem) -> CGPoint? { el.pts.last }

        let out = CGMutablePath()
        func emit(_ el: Elem, _ tf: (CGPoint) -> CGPoint) {
            switch el.type {
            case .moveToPoint: out.move(to: tf(el.pts[0]))
            case .addLineToPoint: out.addLine(to: tf(el.pts[0]))
            case .addQuadCurveToPoint: out.addQuadCurve(to: tf(el.pts[1]), control: tf(el.pts[0]))
            case .addCurveToPoint: out.addCurve(to: tf(el.pts[2]), control1: tf(el.pts[0]), control2: tf(el.pts[1]))
            case .closeSubpath: out.closeSubpath()
            @unknown default: break
            }
        }
        let pAmp = fontSize * 0.045 * CGFloat(pressure)
        let tAmp = fontSize * 0.055 * CGFloat(taper)

        for sub in subpaths {
            // 端点列（moveTo含む・closeSubpath除く）
            let epIdx = sub.filter { elems[$0].type != .closeSubpath }
            let eps = epIdx.compactMap { endpoint(elems[$0]) }
            guard eps.count >= 3 else {
                // 点が少なすぎるサブパスは無変形で通す
                for i in sub { emit(elems[i]) { $0 } }
                continue
            }
            // 符号付き面積: >0 = CCW（外周）, <0 = CW（穴）。normalの向き補正に使う
            var area: CGFloat = 0
            for k in 0..<eps.count {
                let a = eps[k], b = eps[(k + 1) % eps.count]
                area += a.x * b.y - b.x * a.y
            }
            let orient: CGFloat = area >= 0 ? 1 : -1

            // 各端点の外向き法線（前後の端点から接線→垂線）と変形量
            var offsets: [CGPoint] = []
            let n = eps.count
            for k in 0..<n {
                let prev = eps[(k + n - 1) % n], next = eps[(k + 1) % n]
                var tx = next.x - prev.x, ty = next.y - prev.y
                let len = max(sqrt(tx * tx + ty * ty), 0.001)
                tx /= len; ty /= len
                // CCW外周でグリフの外を向く法線
                let nx = ty * orient, ny = -tx * orient
                let s = CGFloat(k) / CGFloat(n)   // サブパス内の位置 0..1
                // 筆圧: 低周波の膨張/収縮（外向き+で太る）
                let w = sin(s * .pi * 2 * 2.3 + seed) * 0.6 + sin(s * .pi * 2 * 4.7 + seed * 1.7) * 0.4
                var d = pAmp * w
                // テーパー: 画の入り(s≈0)と抜き(s≈1)で内側へ痩せる
                let endDist = min(s, 1 - s)
                if endDist < 0.16 { d -= tAmp * (1 - endDist / 0.16) }
                offsets.append(CGPoint(x: nx * d, y: ny * d))
            }
            var epMap: [Int: CGPoint] = [:]
            for (k, i) in epIdx.enumerated() { epMap[i] = offsets[k] }

            // 3) 再構築: 端点はその法線オフセット、制御点は自端点と同じオフセット（滑らかさ維持）
            for i in sub {
                let off = epMap[i] ?? .zero
                emit(elems[i]) { CGPoint(x: $0.x + off.x, y: $0.y + off.y) }
            }
        }
        return out
    }

    /// かすれ筋: グリフのバウンディングボックスを斜めに走る細い線分群。
    /// 呼び出し側がグリフでクリップし blendMode=.destinationOut でストロークして「削る」。
    public static func scratchLines(bbox: CGRect, fontSize: CGFloat,
                                    roughness: Double, seed: CGFloat)
        -> [(from: CGPoint, to: CGPoint, width: CGFloat)] {
        guard roughness > 0.03, bbox.width > 1, bbox.height > 1 else { return [] }
        func h(_ i: Int, _ salt: CGFloat) -> CGFloat {
            abs(sin(CGFloat(i) * 12.9898 + seed * 7.13 + salt) * 43758.5453)
                .truncatingRemainder(dividingBy: 1)
        }
        let count = Int(1 + roughness * 5)
        var lines: [(CGPoint, CGPoint, CGFloat)] = []
        for i in 0..<count {
            // 筆の走りに沿ったほぼ水平の短い削り。破線（dashLengths）で途切れさせ
            // 「連続スラッシュ」でなく「掠れた穂先の跡」にする
            let y0 = bbox.minY + bbox.height * (0.1 + 0.8 * h(i, 1))
            let x0 = bbox.minX + bbox.width * (0.25 * h(i, 5) - 0.05)
            let dx = bbox.width * (0.5 + 0.7 * h(i, 6))
            let dy = bbox.height * (0.03 + 0.09 * h(i, 2)) * (h(i, 3) > 0.5 ? 1 : -1)
            let w = fontSize * (0.008 + 0.016 * h(i, 4)) * CGFloat(0.6 + roughness * 0.8)
            lines.append((CGPoint(x: x0, y: y0), CGPoint(x: x0 + dx, y: y0 + dy), w))
        }
        return lines
    }

    /// かすれ筋の破線パターン（決定的）。呼び出し側が setLineDash に渡す
    public static func scratchDash(fontSize: CGFloat, seed: CGFloat, index: Int) -> [CGFloat] {
        func h(_ salt: CGFloat) -> CGFloat {
            abs(sin(CGFloat(index) * 12.9898 + seed * 7.13 + salt) * 43758.5453)
                .truncatingRemainder(dividingBy: 1)
        }
        return [fontSize * (0.05 + 0.1 * h(11)), fontSize * (0.05 + 0.12 * h(12))]
    }
}

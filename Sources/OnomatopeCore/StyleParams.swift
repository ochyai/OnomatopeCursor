// 描き文字スタイルのパラメータ化 — θ → コミカルな漫画描き文字（Track B）
//
// 「重い語は重く描かれる」を体系化しつつ、BOOM!的なコミカルさを出すためのリッチな
// 描き文字プリミティブ: 極太アウトライン・グラデ塗り・白フチのハロー・文字ごとのバウンド/
// 回転ジッター・スケール変動。θから初期値を導き、夜間の審美探索（Claude審査）がこの空間を
// 進化させる＝コミカルな描き文字が自走生成される。
import Foundation
import CoreGraphics

public struct StyleParams {
    public var fontHeavy: Bool
    public var sizeScale: Double
    public var boilAmp: Double
    public var tilt: Double
    public var hue: Double
    public var saturation: Double
    public var brightness: Double
    public var shadowDepth: Double
    public var speedLines: Int
    // ── コミカル描き文字プリミティブ ──
    public var outlineWidth: Double   // 極太アウトライン（0..1→0..14pt相当）
    public var gradient: Double       // 上明→下暗のグラデ強度 0..1
    public var halo: Double           // 白フチのハロー 0..1
    public var charBounce: Double     // 文字ごとの上下ばらつき 0..1
    public var charRotJitter: Double  // 文字ごとの回転ばらつき 0..1
    public var charScaleJitter: Double// 文字ごとの大小ばらつき 0..1
    // ── 筆のベクター変形（描き文字の深化） ──
    public var pressure: Double = 0.45  // 筆圧: 輪郭の低周波太細 0..1
    public var taper: Double = 0.35     // テーパー: 画の入り抜きの痩せ 0..1
    public var roughness: Double = 0.2  // かすれ: 削り筋の量 0..1

    /// θ → スタイル。ルール写像 h0(θ) に、夜間審美探索から回帰した補正Δ（StyleMap）を足す
    public static func from(theta: [Double]) -> StyleParams {
        let v = clamp(theta.count > 0 ? theta[0] : 0.5)   // 濁音=重さ
        let g = clamp(theta.count > 1 ? theta[1] : 0.5)   // 促音=鋭さ
        let e = clamp(theta.count > 2 ? theta[2] : 0.0)   // 長音=持続
        let r = clamp(theta.count > 3 ? theta[3] : 0.0)   // 反復

        let th = [v, g, e, r]
        // 学習済み h(θ) = h0 + Δ（stylemap.json が無ければ h0 のまま）
        func h(_ field: String, _ base: Double) -> Double {
            StyleMap.shared.adjust(field, base: base, theta: th)
        }
        let hue = clamp(0.55 - 0.53 * v - 0.30 * g + 0.10 * r) * (e > 0.5 ? 0.4 : 1.0)
                  + (e > 0.5 ? 0.55 * 0.6 : 0)
        return StyleParams(
            fontHeavy: v > 0.45 || g > 0.5,
            sizeScale: h("sizeScale", 0.85 + 0.55 * g + 0.35 * v),
            boilAmp: h("boilAmp", 0.03 + 0.05 * v + 0.03 * r),
            tilt: h("tilt", (g - 0.3) * 0.18),
            hue: h("hue", clamp(hue)),
            saturation: h("saturation", 0.55 + 0.4 * (v + g) / 2),
            brightness: h("brightness", 1.0 - 0.15 * v),
            shadowDepth: h("shadowDepth", 0.3 + 0.5 * v + 0.3 * g),
            speedLines: Int(h("speedLines", e > 0.5 ? (2 + e * 3) : 0).rounded()),
            // コミカル: 鋭い・重いほど太アウトライン・強グラデ・大バウンド
            outlineWidth: h("outlineWidth", 0.45 + 0.4 * g + 0.2 * v),   // 常にしっかり縁取る
            gradient: h("gradient", 0.35 + 0.45 * v + 0.2 * g),          // 重いほど深いグラデ
            halo: h("halo", g > 0.5 || v > 0.6 ? 0.8 : 0.4),             // 勢いのある語は白ハロー
            charBounce: h("charBounce", 0.25 + 0.5 * g + 0.3 * r),       // 鋭い・反復でぴょこぴょこ
            charRotJitter: h("charRotJitter", 0.2 + 0.4 * g + 0.3 * r),  // 手描きのばらけ
            charScaleJitter: h("charScaleJitter", 0.15 + 0.35 * (g + r) / 2),
            // 筆: 重い語は筆圧が乗り、鋭い語は入り抜きが速く（テーパー・かすれ）
            pressure: h("pressure", 0.3 + 0.5 * v),
            taper: h("taper", 0.2 + 0.55 * g),
            roughness: h("roughness", 0.1 + 0.35 * g + 0.25 * e))
    }

    private static func clamp(_ v: Double) -> Double { min(max(v, 0), 1) }
}

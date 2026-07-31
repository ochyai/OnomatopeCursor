// カーソル動作 → オノマトペ潜在空間（θ）への写像
//
// これがユーザーの質問「カーソルの動作をオノマトペ潜在空間に変換する方法」への答え:
//   θ = [voicing 重さ, gemination 鋭さ, elongation 持続, reduplication 反復] が
//   動作の運動量とオノマトペ音韻の共通座標系（4次元潜在空間）になる。
//
//   voicing(重さ)     ← 速度と強度（速く大きい動き = 重い音）
//   gemination(鋭さ)  ← ジャーク／急停止（急峻な変化 = 促音）
//   elongation(持続)  ← 直進的な持続移動（長く伸びる = 長音）
//   reduplication(反復)← 方向反転・回転の周期性（繰り返す = 畳語）
//
// この写像で、任意のカーソル運動がθ点になり、OnomaFormerの条件・音韻空間座標・
// 既存語形との距離が全て同じ4次元で測れる。動作→θ→（新）オノマトペが一本の線で繋がる。
import Foundation
import CoreGraphics

public enum MotionToTheta {

    /// 運動特徴量 → θ ∈ [0,1]^4
    public static func theta(from f: MotionFeatures) -> [Double] {
        let s = Double(f.speed)
        let j = Double(f.jerk)
        let flips = Double(f.flipX + f.flipY)
        let turn = abs(Double(f.cumTurn))
        let straight = Double(f.straight)

        // 重さ: 速度（0..30を0..1へ）＋ジャークで加重
        let voicing = clamp(s / 30 * 0.75 + j / 12 * 0.25)
        // 鋭さ: ジャーク主導（急峻な変化）＋高速の締まり
        let gemination = clamp(j / 8 * 0.7 + (s > 20 ? 0.3 : 0))
        // 持続: 直進度×そこそこの速度（まっすぐ長く動く）
        let elongation = clamp(straight * min(s / 12, 1) * 1.1)
        // 反復: 方向反転・回転の存在
        let reduplication = clamp(flips / 5 * 0.7 + min(turn / 6, 1) * 0.5)

        return [round3(voicing), round3(gemination), round3(elongation), round3(reduplication)]
    }

    /// 急停止イベント時の即席θ（鋭さ最大）
    public static let stopTheta: [Double] = [0.6, 0.95, 0.0, 0.0]

    private static func clamp(_ v: Double) -> Double { min(max(v, 0), 1) }
    private static func round3(_ v: Double) -> Double { (v * 1000).rounded() / 1000 }

    /// θ空間での2点間距離（潜在空間HUD・最近傍語の計算用）
    public static func distance(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return .infinity }
        return zip(a, b).map { ($0 - $1) * ($0 - $1) }.reduce(0, +).squareRoot()
    }
}

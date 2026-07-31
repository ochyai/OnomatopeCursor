// 学習済み h(θ) スタイル写像 — 夜間審美探索の採点から回帰した補正を適用する
//
// ml/fit_style_map.py が i18n/stylemap.json を書く:
//   style = clamp( h0(θ) + [1,v,g,e,r]·delta[field] )
// ファイルが無ければ何もしない（ルール写像 h0 のまま）。
import Foundation

public final class StyleMap {
    public static let shared = StyleMap()
    public init() {}   // テスト用に個別インスタンスも作れる（アプリはsharedを使う）

    private var delta: [String: [Double]] = [:]
    private var ranges: [String: (lo: Double, hi: Double)] = [:]
    public private(set) var isLoaded = false

    public func load(from url: URL) {
        guard let data = try? Data(contentsOf: url),
              let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let d = j["delta"] as? [String: [Double]] else { return }
        delta = d.filter { $0.value.count == 5 }
        if let r = j["ranges"] as? [String: [Double]] {
            for (k, v) in r where v.count == 2 { ranges[k] = (v[0], v[1]) }
        }
        isLoaded = !delta.isEmpty
    }

    /// フィールドのルール写像値に学習済みΔを足してクランプ。未学習フィールドは素通し
    public func adjust(_ field: String, base: Double, theta: [Double]) -> Double {
        guard isLoaded, let w = delta[field] else { return base }
        let v = theta.count > 0 ? theta[0] : 0.5
        let g = theta.count > 1 ? theta[1] : 0.5
        let e = theta.count > 2 ? theta[2] : 0
        let r = theta.count > 3 ? theta[3] : 0
        var val = base + w[0] + w[1] * v + w[2] * g + w[3] * e + w[4] * r
        if let rg = ranges[field] { val = min(max(val, rg.lo), rg.hi) }
        return val
    }
}

// 中間語形の生成器 — C_F(θ) の実装
//
// これまで語形はルックアップ（離散語形の表）だった。本生成器は連続θから語形を「合成」する:
//   θ = [voicing 重さ, gemination 鋭さ, elongation 持続, reduplication 反復] ∈ [0,1]^4
//   語幹はvoicingラダー（軽い音→重い音）で選び、促音・長音・反復・感嘆符を規則合成する。
//
// 役割:
//  1. 既存語形の「間」の語形（例: ポチッとカチッの中間 = カチ）を実時間で生成できる
//  2. 生成語は2択クイズで既存語と対戦し、勝敗（Bradley–Terry）で文法自体が更新される
//     = システムが自分で仮説語形を生成→実験→改訂する自己駆動型の形態研究
import Foundation

public enum MorphSynth {

    public enum GemPosition { case prefix, suffix }

    public struct FamilySpec {
        public let name: String
        /// voicingラダー: (この値以上で採用, 語幹)。軽い音→重い音の順
        public let stems: [(v: Double, stem: String)]
        public let gemPosition: GemPosition
        /// 長音挿入位置（語幹の先頭からn文字目の後。多くは1）
        public let elongAfter: Int
    }

    public static let families: [String: FamilySpec] = [
        "click": FamilySpec(name: "click",
                            stems: [(0.0, "ポチ"), (0.40, "カチ"), (0.75, "バチン")],
                            gemPosition: .suffix, elongAfter: 1),
        "enter": FamilySpec(name: "enter",
                            stems: [(0.0, "かん"), (0.20, "たん"), (0.45, "タン"), (0.70, "ドン")],
                            gemPosition: .prefix, elongAfter: 1),
        // 打鍵: 反復前提の打撃音ラダー（r=1でポチポチ→カチャカチャ→カタカタ→ダダダダッ）
        "typing": FamilySpec(name: "typing",
                             stems: [(0.0, "ポチ"), (0.35, "カチャ"), (0.55, "カタ"), (0.80, "ダダ")],
                             gemPosition: .suffix, elongAfter: 1),
        "drop":  FamilySpec(name: "drop",
                            stems: [(0.0, "ポト"), (0.35, "ポイ"), (0.80, "ドサ")],
                            gemPosition: .suffix, elongAfter: 1),
        "edge":  FamilySpec(name: "edge",
                            stems: [(0.0, "コト"), (0.40, "カタ"), (0.75, "ガタ")],
                            gemPosition: .suffix, elongAfter: 1),
        "scroll": FamilySpec(name: "scroll",
                             stems: [(0.0, "スル"), (0.45, "シュル"), (0.80, "ズル")],
                             gemPosition: .suffix, elongAfter: 1),
    ]

    /// 連続θから語形を合成する
    public static func generate(family: String, theta: [Double]) -> String? {
        guard theta.count == 4, let spec = families[family] else { return nil }
        let v = min(max(theta[0], 0), 1)
        let g = min(max(theta[1], 0), 1)
        let e = min(max(theta[2], 0), 1)
        let r = min(max(theta[3], 0), 1)

        // 1) voicingラダーで語幹選択
        var stem = spec.stems.last(where: { v >= $0.v })?.stem ?? spec.stems[0].stem

        // 2) 長音（持続・距離）: 先頭モーラの後に「ー」
        if e > 0.5 {
            let chars = Array(stem)
            if chars.count > spec.elongAfter {
                stem = String(chars[0..<spec.elongAfter]) + "ー" + String(chars[spec.elongAfter...])
            } else {
                stem += "ー"
            }
        }

        // 3) 反復（繰り返し）: 語幹を重ねる（反復時は促音・感嘆符を弱める＝カチカチ调）
        if r > 0.6 {
            let unit = stem
            stem = unit + unit
            if g > 0.6 { stem += "ッ" }
            return stem
        }

        // 4) 促音（鋭さ）と感嘆符
        var out = stem
        if g > 0.35 {
            switch spec.gemPosition {
            case .suffix: out += "ッ"
            case .prefix: out = "ッ" + out
            }
        }
        if g > 0.60 { out += "！" }
        if g > 0.85 { out += "！" }
        return out
    }

    /// 勾配族の各段のおおよそのθ（クイズの中間θ計算・分析用）
    public static let rungTheta: [String: [[Double]]] = [
        "click": [[0.05, 0.1, 0, 0], [0.1, 0.5, 0, 0], [0.5, 0.6, 0, 0], [0.85, 0.95, 0, 0]],
        "enter": [[0.05, 0.05, 0, 0], [0.35, 0.5, 0.4, 0], [0.55, 0.8, 0.5, 0], [0.8, 0.95, 0.6, 0]],
        "drop":  [[0.1, 0.4, 0, 0], [0.4, 0.55, 0.1, 0], [0.5, 0.7, 0.7, 0], [0.9, 0.6, 0.1, 0]],
        "edge":  [[0.1, 0.35, 0, 0], [0.5, 0.5, 0, 0], [0.8, 0.75, 0, 0]],
    ]

    /// 2つの段の中間θ（生成語クイズ用）
    public static func midTheta(family: String, i: Int, j: Int) -> [Double]? {
        guard let rungs = rungTheta[family],
              i >= 0, i < rungs.count, j >= 0, j < rungs.count else { return nil }
        return zip(rungs[i], rungs[j]).map { ($0 + $1) / 2 }
    }
}

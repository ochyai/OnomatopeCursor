// 族アンカー付き生成 — 音源が明確なイベントは語の「族」を守る
//
// 打鍵・Enter・クリック・段差・ドロップは物理的な音源が明確で、対応する
// オノマトペの「族」が音象徴的に決まっている（打鍵=カタカタ系打撃音、
// Enter=ターン/かーん系の単発打）。生成モードの自由度は「族の中の揺らぎ」に
// 限定する:
//   1. θ[0]（voicing）で族の語幹ラダーからシードを選ぶ
//   2. OnomaFormer にシードを語頭強制して続きだけサンプリング（カタ→カタカタッ！）
//   3. 族の許容文字集合を外れたらリトライ → 最後は MorphSynth 合成（族保証）
// カーソル運動（連続動作・音源なし）はこの制約を受けず従来の自由生成のまま。
import Foundation

public enum FamilyGen {

    public struct Family {
        public let name: String
        /// voicingラダー: (この値以上で採用, シード語幹)。軽い音→重い音
        public let seeds: [(v: Double, seed: String)]
        /// 生成語に許す文字（外れたら族の音色が壊れている）
        public let charset: Set<Character>
        /// フォールバック合成に使う MorphSynth 族名
        public let morphFamily: String
    }

    /// 共通で常に許す記号（促音・長音・撥音・感嘆符）
    private static let common: Set<Character> = ["ッ", "ー", "ン", "！", "っ", "ん"]

    public static let families: [String: Family] = [
        // 打鍵: カ行タ行の打撃音（ポチ/コト/カチャ/カタ/ガタ/ダダ）だけ
        "typing": Family(name: "typing",
                         seeds: [(0.0, "ポチ"), (0.30, "コト"), (0.45, "カチャ"),
                                 (0.60, "カタ"), (0.78, "ガタ"), (0.90, "ダダ")],
                         charset: Set("ポチコトカタガダドャチパバピツゴ"),
                         morphFamily: "typing"),
        // Enter: 単発の打ち込み音（かーん/たん/ターン/ッターン/ドン）
        "enter": Family(name: "enter",
                        seeds: [(0.0, "かん"), (0.20, "たん"), (0.45, "タン"), (0.70, "ドン")],
                        charset: Set("かたんタンドー"),
                        morphFamily: "enter"),
        // クリック: ポチ/カチ/バチ
        "click": Family(name: "click",
                        seeds: [(0.0, "ポチ"), (0.40, "カチ"), (0.75, "バチ")],
                        charset: Set("ポチカバパ"),
                        morphFamily: "click"),
        // 窓の段差: コト/カタ/ガタ
        "edge": Family(name: "edge",
                       seeds: [(0.0, "コト"), (0.40, "カタ"), (0.75, "ガタ")],
                       charset: Set("コトカタガゴド"),
                       morphFamily: "edge"),
        // ドロップ: ポト/ポイ/ドサ
        "drop": Family(name: "drop",
                       seeds: [(0.0, "ポト"), (0.35, "ポイ"), (0.80, "ドサ")],
                       charset: Set("ポトイィドサズ"),
                       morphFamily: "drop"),
    ]

    /// θからシード語幹を選ぶ（enterの弱く柔らかい単発打は「かー」= かーん系）
    public static func seed(family: String, theta: [Double]) -> String? {
        guard let spec = families[family] else { return nil }
        let v = min(max(theta.count > 0 ? theta[0] : 0.5, 0), 1)
        let e = min(max(theta.count > 2 ? theta[2] : 0, 0), 1)
        if family == "enter", v < 0.25, e > 0.4 { return "かー" }
        return spec.seeds.last(where: { v >= $0.v })?.seed ?? spec.seeds[0].seed
    }

    /// 生成語が族の音色に収まっているか
    public static func accepts(family: String, word: String) -> Bool {
        guard let spec = families[family] else { return false }
        guard (2...8).contains(word.count) else { return false }
        return word.allSatisfy { spec.charset.contains($0) || common.contains($0) }
    }

    /// 族アンカー付きで1語生成する。OnomaFormerシード生成（≤3回）→ MorphSynth合成。
    /// MorphSynthは族テーブルから必ず合成できるため、familyが正しければ非nil。
    public static func generate(family: String, theta: [Double], cats: [Double] = [],
                                rng: inout SystemRandomNumberGenerator) -> String? {
        guard families[family] != nil else { return nil }
        if let sd = seed(family: family, theta: theta), OnomaFormerCore.shared.isReady {
            for _ in 0..<3 {
                if let w = OnomaFormerCore.shared.generate(theta: theta, cats: cats,
                                                          temperature: 0.9, seed: sd, rng: &rng),
                   accepts(family: family, word: w) {
                    return w
                }
            }
        }
        let mf = families[family]!.morphFamily
        let th = theta.count == 4 ? theta : (theta + [0.0, 0.0, 0.0, 0.0]).prefix(4).map { $0 }
        return MorphSynth.generate(family: mf, theta: Array(th))
    }
}

// OnomaFormer オンデバイス推論（依存ゼロ・Accelerate）
//
// PyTorchで学習しJSON化した重み（i18n/onomaformer.json）を読み、θ条件付きで
// 辞書外のオノマトペを生成する。norm_first Transformer・因果マスク・温度サンプリング。
// coremltools不要——float配列とvDSP/BLASだけで前向き計算する。
import Foundation
import Accelerate

public final class OnomaFormerCore {
    public static let shared = OnomaFormerCore()

    private struct Block {
        let inW: [Float], inB: [Float], outW: [Float], outB: [Float]
        let ln1W: [Float], ln1B: [Float], ln2W: [Float], ln2B: [Float]
        let fc1W: [Float], fc1B: [Float], fc2W: [Float], fc2B: [Float]
    }

    private var loaded = false
    private var chars: [Character] = []
    private var d = 0, heads = 0, vocab = 0, maxlen = 0
    private var tok: [Float] = [], pos: [Float] = []
    private var condW: [Float] = [], condB: [Float] = []
    private var headW: [Float] = [], headB: [Float] = []
    private var blocks: [Block] = []

    public var isReady: Bool { loaded }

    public func load(from url: URL) {
        guard let data = try? Data(contentsOf: url),
              let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        // 2次元配列も平坦化する（行優先）
        func flatten(_ any: Any?) -> [Float] {
            guard let arr = any as? [Any] else { return [] }
            if let n = arr.first as? NSNumber, n.floatValue == n.floatValue {
                return arr.compactMap { ($0 as? NSNumber)?.floatValue }
            }
            return arr.flatMap { flatten($0) }
        }
        func f(_ k: String) -> [Float] { flatten(j[k]) }
        chars = (j["chars"] as? [String])?.compactMap { $0.first } ?? []
        d = j["d"] as? Int ?? 128
        heads = j["heads"] as? Int ?? 4
        vocab = j["vocab"] as? Int ?? (chars.count + 3)
        maxlen = j["maxlen"] as? Int ?? 16
        tok = f("tok"); pos = f("pos")
        condW = f("cond_w"); condB = f("cond_b")
        headW = f("head_w"); headB = f("head_b")
        blocks = (j["blocks"] as? [[String: Any]] ?? []).map { b in
            func g(_ k: String) -> [Float] { flatten(b[k]) }
            return Block(inW: g("in_proj_w"), inB: g("in_proj_b"), outW: g("out_w"), outB: g("out_b"),
                         ln1W: g("ln1_w"), ln1B: g("ln1_b"), ln2W: g("ln2_w"), ln2B: g("ln2_b"),
                         fc1W: g("fc1_w"), fc1B: g("fc1_b"), fc2W: g("fc2_w"), fc2B: g("fc2_b"))
        }
        loaded = !tok.isEmpty && !blocks.isEmpty && chars.count + 3 == vocab
    }

    // ── 線形代数ヘルパ（行優先） ──

    /// y[n×out] = x[n×inp] · W[out×inp]^T + b[out]（PyTorch Linear）
    private func linear(_ x: [Float], n: Int, inp: Int, W: [Float], b: [Float], out: Int) -> [Float] {
        var y = [Float](repeating: 0, count: n * out)
        // C = A(n×inp) * B(inp×out) where B = W^T. cblas: W is out×inp row-major = W^T col-major(inp×out)
        cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasTrans, Int32(n), Int32(out), Int32(inp),
                    1, x, Int32(inp), W, Int32(inp), 0, &y, Int32(out))
        if !b.isEmpty {
            for i in 0..<n { for jj in 0..<out { y[i * out + jj] += b[jj] } }
        }
        return y
    }

    private func layerNorm(_ x: [Float], n: Int, dim: Int, w: [Float], b: [Float]) -> [Float] {
        var y = x
        for i in 0..<n {
            let base = i * dim
            var mean: Float = 0; vDSP_meanv(Array(x[base..<base+dim]), 1, &mean, vDSP_Length(dim))
            var vr: Float = 0
            for k in 0..<dim { let dv = x[base+k]-mean; vr += dv*dv }
            vr /= Float(dim)
            let inv = 1 / (vr + 1e-5).squareRoot()
            for k in 0..<dim { y[base+k] = (x[base+k]-mean)*inv*w[k] + b[k] }
        }
        return y
    }

    private func gelu(_ x: inout [Float]) {
        for i in 0..<x.count {
            let v = x[i]
            x[i] = 0.5 * v * (1 + tanh(0.7978845608 * (v + 0.044715 * v * v * v)))
        }
    }

    private func selfAttention(_ x: [Float], n: Int, blk: Block) -> [Float] {
        // in_proj: [3d × d] → Q,K,V each [n×d]
        let qkv = linear(x, n: n, inp: d, W: blk.inW, b: blk.inB, out: 3 * d)
        var q = [Float](repeating: 0, count: n*d), k = q, v = q
        for i in 0..<n {
            for j in 0..<d {
                q[i*d+j] = qkv[i*3*d + j]
                k[i*d+j] = qkv[i*3*d + d + j]
                v[i*d+j] = qkv[i*3*d + 2*d + j]
            }
        }
        let hd = d / heads
        let scale = 1 / Float(hd).squareRoot()
        var ctx = [Float](repeating: 0, count: n*d)
        for h in 0..<heads {
            let off = h*hd
            for i in 0..<n {
                var scores = [Float](repeating: 0, count: i+1)   // 因果マスク: j<=i
                for jj in 0...i {
                    var s: Float = 0
                    for t in 0..<hd { s += q[i*d+off+t] * k[jj*d+off+t] }
                    scores[jj] = s * scale
                }
                // softmax
                let mx = scores.max() ?? 0
                var sum: Float = 0
                for jj in 0...i { scores[jj] = exp(scores[jj]-mx); sum += scores[jj] }
                for jj in 0...i {
                    let w = scores[jj]/sum
                    for t in 0..<hd { ctx[i*d+off+t] += w * v[jj*d+off+t] }
                }
            }
        }
        return linear(ctx, n: n, inp: d, W: blk.outW, b: blk.outB, out: d)
    }

    /// 条件次元（θ4 + 意味カテゴリ6 = 10）。旧4次元モデルとも互換
    private var condDim: Int { condW.count / max(d, 1) }

    /// 最終位置のlogitsを返す（条件付き・因果）
    private func forwardLast(ids: [Int], cond condVec: [Float]) -> [Float] {
        let n = ids.count
        let cond = linear(condVec, n: 1, inp: condDim, W: condW, b: condB, out: d)   // [d]
        var h = [Float](repeating: 0, count: n*d)
        for i in 0..<n {
            for j in 0..<d { h[i*d+j] = tok[ids[i]*d + j] + pos[i*d + j] + cond[j] }
        }
        for blk in blocks {
            // norm_first: x = x + attn(ln1(x)); x = x + ff(ln2(x))
            let a = selfAttention(layerNorm(h, n: n, dim: d, w: blk.ln1W, b: blk.ln1B), n: n, blk: blk)
            for i in 0..<n*d { h[i] += a[i] }
            var f1 = linear(layerNorm(h, n: n, dim: d, w: blk.ln2W, b: blk.ln2B),
                            n: n, inp: d, W: blk.fc1W, b: blk.fc1B, out: blk.fc1B.count)
            gelu(&f1)
            let f2 = linear(f1, n: n, inp: blk.fc1B.count, W: blk.fc2W, b: blk.fc2B, out: d)
            for i in 0..<n*d { h[i] += f2[i] }
        }
        // 最終位置のみhead
        let last = Array(h[(n-1)*d ..< n*d])
        return linear(last, n: 1, inp: d, W: headW, b: headB, out: vocab)
    }

    public static let categories = ["impact", "motion", "texture", "emotion", "light", "wetdry"]

    /// θ(+意味カテゴリ)を指定して新オノマトペを1語サンプリング（bos=1, eos=2, char i -> id i+3）
    /// cats: categories と同順の0/1（省略時は全0）。旧4次元モデルではθのみ使う
    /// seed: 語頭を強制するプレフィックス（族アンカー生成）。語彙外文字を含む場合はnil
    public func generate(theta: [Double], cats: [Double] = [],
                         temperature: Double = 0.95,
                         seed: String = "",
                         rng: inout SystemRandomNumberGenerator) -> String? {
        guard loaded else { return nil }
        var cond = theta.map { Float(min(max($0, 0), 1)) }
        if condDim > 4 {
            let c6 = (cats + Array(repeating: 0.0, count: 6)).prefix(6).map { Float(min(max($0, 0), 1)) }
            cond += c6
        }
        var ids = [1]
        var out = ""
        for c in seed {
            guard let idx = chars.firstIndex(of: c), ids.count < maxlen - 1 else { return nil }
            ids.append(idx + 3)
            out.append(c)
        }
        // 位置埋め込みはmaxlen分しかない。シード込みでidsがmaxlenを超えないこと
        // （固定回数ループだとシード長のぶん超過し pos[] が範囲外になる）
        while ids.count < maxlen {
            let logits = forwardLast(ids: ids, cond: cond)
            // 温度ソフトマックス（max減算で数値安定化） → サンプリング
            let scaled = logits.map { $0 / Float(temperature) }
            let mx = scaled.max() ?? 0
            let probs = scaled.map { exp($0 - mx) }
            let sum = probs.reduce(0, +)
            let r = Float.random(in: 0..<1, using: &rng) * sum
            var acc: Float = 0, nxt = 2
            for (i, p) in probs.enumerated() { acc += p; if acc >= r { nxt = i; break } }
            if nxt == 2 { break }
            if nxt >= 3 && nxt - 3 < chars.count { out.append(chars[nxt - 3]) }
            ids.append(nxt)
        }
        return (2...8).contains(out.count) ? out : nil
    }
}

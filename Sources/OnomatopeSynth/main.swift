// 合成軌跡データ生成（ML Phase A蒸留用）
//   swift run onomatope-synth ml/logs-synth 30
// 多様なパターンの軌跡を生成し、実物のMotionTracker+classifyMotionでラベル付けして
// アプリの研究ログと同形式のJSONLを書き出す。
import Foundation
import CoreGraphics
import OnomatopeCore

// 再現可能な乱数（SplitMix64）
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

let args = CommandLine.arguments
// 出力先のサニタイズ: カレントディレクトリ配下のみ許可（絶対パス・..を拒否）
let rawOut = args.count > 1 ? args[1] : "ml/logs-synth"
let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    .standardizedFileURL
let candidate = URL(fileURLWithPath: rawOut, isDirectory: true,
                    relativeTo: cwd).standardizedFileURL
guard !rawOut.hasPrefix("/"), !rawOut.hasPrefix("~"),
      candidate.path.hasPrefix(cwd.path + "/") || candidate.path == cwd.path else {
    fputs("出力ディレクトリはカレントディレクトリ配下の相対パスのみ許可: \(rawOut)\n", stderr)
    exit(1)
}
let outDir = candidate
let nSessions = args.count > 2 ? Int(args[2]) ?? 30 : 30
let sessionSec = 60.0
let dt = 1.0 / 60.0

try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

var rng = SplitMix64(state: 20260716)

func u(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat { CGFloat.random(in: lo...hi, using: &rng) }
func choice<T>(_ xs: [T]) -> T { xs.randomElement(using: &rng)! }

// 1セグメント分の軌跡を生成（現在位置から）
func segment(from start: CGPoint) -> [CGPoint] {
    var p = start
    var pts: [CGPoint] = []
    let kind = choice(["line", "circle", "zigx", "zigy", "tremor", "wander", "dash", "pause"])
    let frames = Int(u(60, 240))
    switch kind {
    case "line":
        let speed = u(0.5, 38)
        let a = u(0, 2 * .pi)
        for _ in 0..<frames { p.x += cos(a) * speed; p.y += sin(a) * speed; pts.append(p) }
    case "circle":
        let speed = u(5, 20)
        let w = u(0.05, 0.25) * (Bool.random(using: &rng) ? 1 : -1)
        var a = u(0, 2 * .pi)
        for _ in 0..<frames { a += w; p.x += cos(a) * speed; p.y += sin(a) * speed; pts.append(p) }
    case "zigx", "zigy":
        let speed = u(3, 28)
        let leg = Int(u(5, 14))
        var dir: CGFloat = 1
        for i in 0..<frames {
            if i % leg == 0 { dir = -dir }
            if kind == "zigx" { p.x += dir * speed } else { p.y += dir * speed }
            pts.append(p)
        }
    case "tremor":
        let amp = u(0.4, 1.0)
        for i in 0..<frames {
            let s: CGFloat = i % 2 == 0 ? amp : -amp
            pts.append(CGPoint(x: start.x + s, y: start.y + s * 0.8))
        }
    case "wander":
        let speed = u(3, 15)
        var h = u(0, 2 * .pi)
        for _ in 0..<frames {
            h += u(-0.18, 0.18)
            p.x += cos(h) * speed; p.y += sin(h) * speed
            pts.append(p)
        }
    case "dash":
        // 高速→急停止（ピタッ!!/onset用）
        let speed = u(26, 45)
        let a = u(0, 2 * .pi)
        let go = Int(u(20, 45))
        for _ in 0..<go { p.x += cos(a) * speed; p.y += sin(a) * speed; pts.append(p) }
        for _ in 0..<(frames - go) { pts.append(p) }
    default: // pause
        for _ in 0..<frames { pts.append(p) }
    }
    return pts
}

let totalFrames = Int(sessionSec / dt)
for s in 0..<nSessions {
    let tracker = MotionTracker()
    var lines: [String] = [
        #"{"type":"meta","app_version":"synth","ts":0,"screen_w":3000,"screen_h":2000}"#
    ]
    var pos = CGPoint(x: 1500, y: 1000)
    var prev = pos
    var frame = 0
    while frame < totalFrames {
        for p in segment(from: pos) {
            guard frame < totalFrames else { break }
            // 画面内に閉じ込める（実データ同様）
            pos = CGPoint(x: min(max(p.x, 0), 3000), y: min(max(p.y, 0), 2000))
            let dx = pos.x - prev.x
            let dy = pos.y - prev.y
            prev = pos
            let f = tracker.update(position: pos, at: Double(frame) * dt)
            let word = classifyMotion(f) ?? ""
            func r2(_ v: CGFloat) -> Double { (Double(v) * 100).rounded() / 100 }
            lines.append("""
            {"ts":\(Double(frame) * dt),"x":\(r2(pos.x)),"y":\(r2(pos.y)),\
            "dx":\(r2(dx)),"dy":\(r2(dy)),"speed":\(r2(f.speed)),"jerk":\(r2(f.jerk)),\
            "fx":\(f.flipX),"fy":\(f.flipY),"turn":\(r2(f.cumTurn)),\
            "straight":\(r2(f.straight)),"path":\(r2(f.pathLen)),"word":"\(word)"}
            """.replacingOccurrences(of: "\n", with: ""))
            frame += 1
        }
    }
    let url = outDir.appendingPathComponent(String(format: "session-synth-%03d.jsonl", s))
    try lines.joined(separator: "\n").appending("\n").write(to: url, atomically: true, encoding: .utf8)
}
print("wrote \(nSessions) sessions x \(Int(sessionSec))s to \(outDir.path)")

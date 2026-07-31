// 運動特徴量トラッカーと分類器（AppKit非依存・テスト可能）
// 60Hzでカーソル座標を与えると特徴量を返し、classifyMotion() が語を選ぶ。
import Foundation
import CoreGraphics

/// 1フレーム分の運動特徴量
public struct MotionFeatures {
    public var speed: CGFloat = 0        // 指数移動平均 px/frame
    public var jerk: CGFloat = 0         // 速度変化の荒さ（EMA）
    public var flipX: Int = 0            // 0.6s窓の左右反転回数
    public var flipY: Int = 0            // 0.6s窓の上下反転回数
    public var cumTurn: CGFloat = 0      // 0.7s窓の累積回転角 rad
    public var pathLen: CGFloat = 0      // 0.45s窓の経路長
    public var straight: CGFloat = 0     // 0.45s窓の直進度（変位/経路長）
    public var idleSec: CGFloat = 0      // 静止継続秒
    public var dirX: CGFloat = 1         // 直近の水平方向（±1）
    public var teleported: Bool = false  // 瞬間移動を検出しこのフレームを棄却した
    public var pita: Bool = false        // 急停止イベント（このフレームで発火）
    public var onset: Bool = false       // 動き出しイベント（静止→急な動き。即応の暫定語用）
    public var rawD: CGFloat = 0         // このフレームの移動距離

    public init() {}
}

/// 運動語（ml/train_trajectory.py の LABELS と順序含め一致させること）
public let motionWords = [
    "キョロキョロ", "オロオロ", "ソロソロ", "ジリジリ", "グルグル", "クルクル",
    "ビューン", "ピタッ!!", "プルプル", "スーッ", "スイスイ", "ブンブン",
    "ピョンピョン", "ダダダッ", "ウロウロ",
]

/// 不随意の身体状態・情動を名指しうる語（スティグマ配慮でユーザーが非表示にできる）
public let stateNamingWords: Set<String> = ["プルプル", "オロオロ", "ドキドキ", "そわそわ", "もじもじ", "ビクビクッ", "ムズムズ"]

/// 特徴量から語を選ぶ（上から優先。閾値の単位は pt/名目フレーム @60Hz・ジッター補正済み）
public func classifyMotion(_ f: MotionFeatures) -> String? {
    let flips = f.flipX + f.flipY
    let S = f.speed
    let J = f.jerk

    if abs(f.cumTurn) > 6.5 && f.pathLen > 120 { return "グルグル" }               // 回り続ける
    if abs(f.cumTurn) > 3.5 && f.pathLen > 80 { return "クルクル" }                // 軽い回転
    if f.flipX >= 3 && S > 18 { return "ブンブン" }                                 // 激しい左右往復
    if f.flipX >= 3 && S > 2.5 && f.flipY <= f.flipX { return "キョロキョロ" }      // 左右往復
    if f.flipY >= 3 && f.flipY > f.flipX && S > 3 { return "ピョンピョン" }         // 上下ホップ
    if flips >= 5 && S < 3 { return "プルプル" }                                    // その場微振動
    if S > 25 && f.straight <= 0.80 { return "ダダダッ" }                           // 高速で荒い
    if S > 25 { return "ビューン" }                                                 // 高速直線
    if S > 5 && S <= 25 && f.straight > 0.92 && J < 4 { return "スーッ" }           // なめらか直線
    if S > 8 && S <= 25 && f.straight > 0.55 && J < 6 && abs(f.cumTurn) > 1.2 { return "スイスイ" } // なめらか曲線
    if S > 3.5 && S <= 25 && f.straight < 0.55 && flips < 3 { return "ウロウロ" }   // あてもなく徘徊
    if J > 6 && S > 6 { return "オロオロ" }                                         // 不規則
    if S >= 1.2 && S < 3.5 { return "ソロソロ" }                                    // ゆっくり慎重
    if S > 0.3 && S < 1.2 { return "ジリジリ" }                                     // にじり寄る
    return nil
}

/// カーソル座標の系列から特徴量を逐次計算する（60Hz前提）
public final class MotionTracker {
    private var lastPos: CGPoint?
    private var prevVel = CGPoint.zero
    private var speedAvg: CGFloat = 0
    private var jerkAvg: CGFloat = 0
    private var lastD: CGFloat = 0
    private var prevRawD: CGFloat = 0
    private var idleSec: CGFloat = 0
    private var lastDxSign = 0
    private var lastDySign = 0
    private var flipXTimes: [TimeInterval] = []
    private var flipYTimes: [TimeInterval] = []
    private var turnSamples: [(t: TimeInterval, a: CGFloat)] = []
    private var posSamples: [(t: TimeInterval, p: CGPoint, d: CGFloat)] = []
    private var lastFastTime: TimeInterval = -10
    private var lastPitaTime: TimeInterval = -10
    private var lastOnsetTime: TimeInterval = -10
    private var stillFrames = 0
    private var dirX: CGFloat = 1

    public init() {}

    /// 一時停止解除・スリープ復帰時に呼ぶ（位置差分のスパイク防止）
    public func resetPosition(_ p: CGPoint) {
        lastPos = p
        lastD = 0
        prevVel = .zero
    }

    private var lastTime: TimeInterval = -1

    public func update(position p: CGPoint, at now: TimeInterval) -> MotionFeatures {
        guard let last = lastPos else {
            lastPos = p
            lastTime = now
            return MotionFeatures()
        }
        let dx = p.x - last.x
        let dy = p.y - last.y
        // タイマージッター補正: 実測dtで名目60Hzフレームに正規化する。
        // 座標はポイント単位（Retina/DPI非依存）、サンプリングはディスプレイ非依存の
        // 60Hzタイマーなので、閾値は「pt/名目フレーム」として機種間で一貫する。
        let dt = lastTime > 0 ? max(now - lastTime, 1.0 / 240.0) : 1.0 / 60.0
        let jitterScale = min(max((1.0 / 60.0) / dt, 0.25), 4.0)
        let d = hypot(dx, dy) * jitterScale
        lastTime = now
        lastPos = p

        // スリープ復帰・別画面ワープなどの「瞬間移動」はこのフレームを棄却
        if d > 300 {
            lastD = 0
            prevVel = .zero
            var f = snapshot(now: now, rawD: 0)
            f.teleported = true
            return f
        }

        speedAvg = speedAvg * 0.85 + d * 0.15
        jerkAvg = jerkAvg * 0.85 + abs(d - lastD) * 0.15
        lastD = d
        if speedAvg > 22 { lastFastTime = now }   // ピタッ!!の前提となる「高速」
        if dx != 0 || dy != 0 { dirX = dx >= 0 ? 1 : -1 }

        // 左右・上下の反転検出
        let sx = dx > 1 ? 1 : (dx < -1 ? -1 : 0)
        if sx != 0 {
            if lastDxSign != 0 && sx != lastDxSign { flipXTimes.append(now) }
            lastDxSign = sx
        }
        let sy = dy > 1 ? 1 : (dy < -1 ? -1 : 0)
        if sy != 0 {
            if lastDySign != 0 && sy != lastDySign { flipYTimes.append(now) }
            lastDySign = sy
        }
        flipXTimes.removeAll { now - $0 > 0.6 }
        flipYTimes.removeAll { now - $0 > 0.6 }

        // 角速度。ほぼ180°の反転(dot<=0)は往復運動なので回転として積算しない
        // （±πのランダムウォークでグルグル誤判定するのを防ぐ）
        if d > 1.5 && hypot(prevVel.x, prevVel.y) > 1.5 {
            let cross = prevVel.x * dy - prevVel.y * dx
            let dot = prevVel.x * dx + prevVel.y * dy
            if dot > 0 {
                turnSamples.append((now, atan2(cross, dot)))
            }
        }
        turnSamples.removeAll { now - $0.t > 0.7 }
        prevVel = CGPoint(x: dx, y: dy)

        posSamples.append((now, p, d))
        posSamples.removeAll { now - $0.t > 0.45 }

        idleSec = d < 0.5 ? idleSec + 1.0 / 60.0 : 0

        var f = snapshot(now: now, rawD: d)

        // ピタッ!! — 高速移動直後の急停止（3秒クールダウン）
        if now - lastFastTime < 0.12 && d < 0.6 && prevRawD < 0.6 && now - lastPitaTime > 3.0 {
            f.pita = true
            lastPitaTime = now
        }

        // 動き出しイベント — 0.3秒以上の静止から急に動いた瞬間（EMA収束を待たない即応の起点）
        if stillFrames >= 18 && d > 6 && now - lastOnsetTime > 1.0 {
            f.onset = true
            lastOnsetTime = now
        }
        stillFrames = d < 1.0 ? stillFrames + 1 : 0

        prevRawD = d
        return f
    }

    private func snapshot(now: TimeInterval, rawD: CGFloat) -> MotionFeatures {
        var f = MotionFeatures()
        f.speed = speedAvg
        f.jerk = jerkAvg
        f.flipX = flipXTimes.count
        f.flipY = flipYTimes.count
        f.cumTurn = turnSamples.reduce(0) { $0 + $1.a }
        f.pathLen = posSamples.reduce(0) { $0 + $1.d }
        if let first = posSamples.first, let last = posSamples.last, f.pathLen > 8 {
            f.straight = hypot(last.p.x - first.p.x, last.p.y - first.p.y) / f.pathLen
        }
        f.idleSec = idleSec
        f.dirX = dirX
        f.rawD = rawD
        return f
    }
}

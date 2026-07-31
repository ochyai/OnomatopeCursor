// OnomatopeCore テストランナー（XCTest非依存）
//   実行: swift run onomatope-tests
// 合成軌跡（60Hz）を分類器・トラッカー・ロガーに流し込み、期待する挙動を確認する。
import Foundation
import CoreGraphics
import OnomatopeCore

// MARK: - ミニテストハーネス

var passed = 0
var failed = 0
var currentTest = ""

func test(_ name: String, _ body: () throws -> Void) {
    currentTest = name
    do {
        try body()
        passed += 1
        print("  ✓ \(name)")
    } catch {
        failed += 1
        print("  ✗ \(name): \(error)")
    }
}

struct AssertionError: Error, CustomStringConvertible {
    let description: String
}

func expect(_ cond: Bool, _ msg: @autoclosure () -> String, line: Int = #line) throws {
    if !cond { throw AssertionError(description: "L\(line): \(msg())") }
}

func expectEq<T: Equatable>(_ a: T, _ b: T, _ msg: @autoclosure () -> String = "", line: Int = #line) throws {
    if a != b { throw AssertionError(description: "L\(line): \(a) != \(b) \(msg())") }
}

// MARK: - 合成軌跡ジェネレータ

let DT: TimeInterval = 1.0 / 60.0

func line(speed: CGFloat, angle: CGFloat = 0, frames: Int, from start: CGPoint = CGPoint(x: 500, y: 500)) -> [CGPoint] {
    (0..<frames).map { i in
        CGPoint(x: start.x + cos(angle) * speed * CGFloat(i),
                y: start.y + sin(angle) * speed * CGFloat(i))
    }
}

func circlePath(speed: CGFloat, angularStep: CGFloat, frames: Int) -> [CGPoint] {
    let radius = speed / angularStep
    return (0..<frames).map { i in
        let a = angularStep * CGFloat(i)
        return CGPoint(x: 800 + radius * cos(a), y: 500 + radius * sin(a))
    }
}

func zigzag(axis: Int, speed: CGFloat, framesPerLeg: Int, frames: Int) -> [CGPoint] {
    var p = CGPoint(x: 500, y: 500)
    var dir: CGFloat = 1
    var pts: [CGPoint] = [p]
    for i in 1..<frames {
        if i % framesPerLeg == 0 { dir = -dir }
        if axis == 0 { p.x += dir * speed } else { p.y += dir * speed }
        pts.append(p)
    }
    return pts
}

func headingPath(speed: CGFloat, headings: [CGFloat], from start: CGPoint = CGPoint(x: 500, y: 500)) -> [CGPoint] {
    var p = start
    var pts: [CGPoint] = [p]
    for h in headings {
        p.x += cos(h) * speed
        p.y += sin(h) * speed
        pts.append(p)
    }
    return pts
}

func run(_ points: [CGPoint]) -> (features: [MotionFeatures], words: [String?]) {
    let tracker = MotionTracker()
    var feats: [MotionFeatures] = []
    var words: [String?] = []
    for (i, p) in points.enumerated() {
        let f = tracker.update(position: p, at: TimeInterval(i) * DT)
        feats.append(f)
        words.append(classifyMotion(f))
    }
    return (feats, words)
}

func settledWord(_ points: [CGPoint], skip: Int = 45) -> String? {
    let (_, words) = run(points)
    return words.count > skip ? words.last ?? nil : nil
}

// MARK: - 分類器テスト

print("== 分類器（各語） ==")

test("ビューン: 高速直線") {
    try expectEq(settledWord(line(speed: 30, frames: 60)), "ビューン")
}

test("スーッ: 中速なめらか直線") {
    try expectEq(settledWord(line(speed: 12, frames: 60)), "スーッ")
}

test("ソロソロ: 低速") {
    try expectEq(settledWord(line(speed: 2, frames: 60)), "ソロソロ")
}

test("ジリジリ: 極低速") {
    try expectEq(settledWord(line(speed: 0.7, frames: 60)), "ジリジリ")
}

test("グルグル: 回り続ける円") {
    try expectEq(settledWord(circlePath(speed: 10, angularStep: 0.18, frames: 90)), "グルグル")
}

test("クルクル: 軽い回転") {
    try expectEq(settledWord(circlePath(speed: 8, angularStep: 0.10, frames: 90)), "クルクル")
}

test("キョロキョロ: 左右スキャン") {
    try expectEq(settledWord(zigzag(axis: 0, speed: 8, framesPerLeg: 8, frames: 90)), "キョロキョロ")
}

test("ブンブン: 激しい左右往復") {
    try expectEq(settledWord(zigzag(axis: 0, speed: 22, framesPerLeg: 6, frames: 90)), "ブンブン")
}

test("ピョンピョン: 上下ホップ") {
    try expectEq(settledWord(zigzag(axis: 1, speed: 8, framesPerLeg: 8, frames: 90)), "ピョンピョン")
}

test("プルプル: その場微振動") {
    // 位置±0.7の反転 → 毎フレーム約1.9px移動（速度<2.5でキョロキョロ帯域に入らない）
    var pts: [CGPoint] = []
    for i in 0..<90 {
        let s: CGFloat = i % 2 == 0 ? 0.7 : -0.7
        pts.append(CGPoint(x: 500 + s, y: 500 + s * 0.9))
    }
    try expectEq(settledWord(pts), "プルプル")
}

test("オロオロ: 速度が荒れる（高ジャーク）") {
    var p = CGPoint(x: 500, y: 500)
    var pts: [CGPoint] = [p]
    for i in 1..<90 {
        p.x += i % 2 == 0 ? 2 : 14
        pts.append(p)
    }
    try expectEq(settledWord(pts), "オロオロ")
}

test("ダダダッ: 高速×低直進度がどこかで出る") {
    var headings: [CGFloat] = []
    for leg in 0..<8 {
        let h: CGFloat = (leg % 2 == 0 ? 1 : -1) * .pi / 4
        headings += Array(repeating: h, count: 15)
    }
    let (_, words) = run(headingPath(speed: 32, headings: headings))
    try expect(words.compactMap { $0 }.contains("ダダダッ"),
               "出た語: \(Set(words.compactMap { $0 }))")
}

test("ウロウロ: 徘徊がどこかで出る") {
    var headings: [CGFloat] = []
    var h: CGFloat = 0
    for leg in 0..<12 {
        let turn: CGFloat = (leg % 2 == 0 ? 1 : -1) * 0.157
        for _ in 0..<20 { h += turn; headings.append(h) }
    }
    let (_, words) = run(headingPath(speed: 8, headings: headings))
    try expect(words.compactMap { $0 }.contains("ウロウロ"),
               "出た語: \(Set(words.compactMap { $0 }))")
}

test("スイスイ: ゆるい曲線") {
    try expectEq(settledWord(circlePath(speed: 15, angularStep: 0.05, frames: 90)), "スイスイ")
}

print("== 回帰テスト（コードレビュー所見） ==")

test("[回帰] 左右往復が回転語に誤判定されない") {
    for speed in [CGFloat(6), 10, 15, 22] {
        for legs in [5, 8, 12] {
            let (_, words) = run(zigzag(axis: 0, speed: speed, framesPerLeg: legs, frames: 120))
            let bad = words.compactMap { $0 }.filter { $0 == "グルグル" || $0 == "クルクル" }
            try expect(bad.isEmpty, "往復(speed=\(speed), legs=\(legs))で回転語が\(bad.count)回発火")
        }
    }
}

test("[回帰] 中速×低直進度の徘徊で語が途切れない") {
    var headings: [CGFloat] = []
    var h: CGFloat = 0
    for leg in 0..<12 {
        let turn: CGFloat = (leg % 2 == 0 ? 1 : -1) * 0.157
        for _ in 0..<20 { h += turn; headings.append(h) }
    }
    let (feats, words) = run(headingPath(speed: 15, headings: headings))
    for (i, w) in words.enumerated() where i > 45 && w == nil {
        let f = feats[i]
        try expect(!(f.speed > 3.5 && f.speed <= 25 && f.straight < 0.55
                     && f.flipX + f.flipY < 3 && abs(f.cumTurn) <= 3.5),
                   "frame \(i): 中速徘徊なのに語なし speed=\(f.speed) straight=\(f.straight)")
    }
}

print("== イベント・ガード ==")

test("ピタッ!!: 高速→急停止で発火") {
    var pts = line(speed: 30, frames: 50)
    pts += Array(repeating: pts.last!, count: 20)
    let (feats, _) = run(pts)
    try expect(feats.contains { $0.pita }, "発火しない")
}

test("ピタッ!!: 3秒クールダウンで連発しない") {
    var pts = line(speed: 30, frames: 50)
    pts += Array(repeating: pts.last!, count: 10)
    pts += line(speed: 30, frames: 30, from: pts.last!)
    pts += Array(repeating: pts.last!, count: 10)
    let (feats, _) = run(pts)
    try expectEq(feats.filter { $0.pita }.count, 1)
}

test("ピタッ!!: 低速からの停止では発火しない") {
    var pts = line(speed: 8, frames: 60)
    pts += Array(repeating: pts.last!, count: 20)
    let (feats, _) = run(pts)
    try expect(!feats.contains { $0.pita }, "低速停止で発火した")
}

test("瞬間移動（別画面ワープ）はフレーム棄却され速度がスパイクしない") {
    var pts = line(speed: 5, frames: 50)
    pts.append(CGPoint(x: pts.last!.x + 2000, y: pts.last!.y))
    pts += line(speed: 5, frames: 5, from: pts.last!)
    let (feats, _) = run(pts)
    try expect(feats[50].teleported, "瞬間移動が検出されない")
    try expect(feats[52].speed < 10, "ワープ後に速度スパイク: \(feats[52].speed)")
}

test("動き出しイベント: 静止→急な動きで即発火") {
    var pts = Array(repeating: CGPoint(x: 500, y: 500), count: 30)   // 0.5秒静止
    pts += line(speed: 15, frames: 10, from: CGPoint(x: 500, y: 500))
    let (feats, _) = run(pts)
    guard let onsetIdx = feats.firstIndex(where: { $0.onset }) else {
        throw AssertionError(description: "onsetが発火しない")
    }
    try expect(onsetIdx <= 32, "発火が遅い: frame \(onsetIdx)（静止明け2フレーム以内であるべき）")
}

test("動き出しイベント: ソロソロの開始（低速）では発火しない") {
    var pts = Array(repeating: CGPoint(x: 500, y: 500), count: 30)
    pts += line(speed: 2, frames: 30, from: CGPoint(x: 500, y: 500))
    let (feats, _) = run(pts)
    try expect(!feats.contains { $0.onset }, "低速開始でonsetが発火した")
}

test("動き出しイベント: 1秒クールダウンで連発しない") {
    var pts = Array(repeating: CGPoint(x: 500, y: 500), count: 30)
    pts += line(speed: 15, frames: 8, from: CGPoint(x: 500, y: 500))
    let mid = pts.last!
    pts += Array(repeating: mid, count: 25)   // 0.42秒静止（クールダウン1秒未満）
    pts += line(speed: 15, frames: 8, from: mid)
    let (feats, _) = run(pts)
    try expectEq(feats.filter { $0.onset }.count, 1, "クールダウン内に2回発火")
}

test("静止でidleSecが積み上がる") {
    var pts = line(speed: 5, frames: 30)
    pts += Array(repeating: pts.last!, count: 120)
    let (feats, _) = run(pts)
    try expect(feats.last!.idleSec > 1.5, "idleSec=\(feats.last!.idleSec)")
}

test("初回フレームはニュートラル") {
    let tracker = MotionTracker()
    let f = tracker.update(position: CGPoint(x: 100, y: 100), at: 0)
    try expectEq(f.speed, 0)
    try expect(classifyMotion(f) == nil, "初回から語が出た")
}

test("resetPosition後のフレームでスパイクしない") {
    let tracker = MotionTracker()
    for (i, p) in line(speed: 5, frames: 30).enumerated() {
        _ = tracker.update(position: p, at: TimeInterval(i) * DT)
    }
    tracker.resetPosition(CGPoint(x: 5000, y: 5000))
    let f = tracker.update(position: CGPoint(x: 5003, y: 5000), at: 31 * DT)
    try expect(f.speed < 10, "reset後にspeed=\(f.speed)")
}

test("言語パック: 4言語×52語形が完全で θ∈[0,1]^4") {
    let store = VocabularyStore()
    store.load(from: URL(fileURLWithPath: "i18n"))
    try expectEq(Set(store.packs.keys), Set(["en", "zh", "ko", "fr"]), "言語が揃っていない")
    for (lang, pack) in store.packs {
        try expectEq(pack.forms.count, 61, "\(lang)の語形数")
        for (k, f) in pack.forms {
            try expect(!f.form.isEmpty, "\(lang)/\(k)が空")
            try expect(f.theta.count == 4 && f.theta.allSatisfy { $0 >= 0 && $0 <= 1 },
                       "\(lang)/\(k)のθが不正: \(f.theta)")
        }
    }
}

test("言語パック: canonical→localize往復（ja=そのまま/en=英語形）") {
    let store = VocabularyStore()
    store.load(from: URL(fileURLWithPath: "i18n"))
    store.currentLang = "ja"
    try expectEq(store.localize("ピタッ!!"), "ピタッ!!")
    store.currentLang = "en"
    try expect(store.localize("ピタッ!!") != "ピタッ!!", "英語形に解決されていない")
    try expectEq(store.localize("未知の語"), "未知の語", "未収録はcanonicalのままであるべき")
}

test("語彙リストは15語・重複なし（ml/LABELSと同数）") {
    try expectEq(motionWords.count, 15)
    try expectEq(Set(motionWords).count, 15)
}

// MARK: - 形態生成器テスト（動作の質→語形の単調性）

print("== 形態生成（語形の揺らぎ） ==")

test("クリック: 接近速度で ポチ→ポチッ→カチッ→バチンッ と強くなる") {
    try expectEq(OnomatopeMorphology.clickWord(approachSpeed: 0.5, pressDuration: 0, clickCount: 1), "ポチ")
    try expectEq(OnomatopeMorphology.clickWord(approachSpeed: 3, pressDuration: 0, clickCount: 1), "ポチッ")
    try expectEq(OnomatopeMorphology.clickWord(approachSpeed: 10, pressDuration: 0, clickCount: 1), "カチッ")
    try expectEq(OnomatopeMorphology.clickWord(approachSpeed: 25, pressDuration: 0, clickCount: 1), "バチンッ")
    try expectEq(OnomatopeMorphology.clickWord(approachSpeed: 3, pressDuration: 0, clickCount: 2), "カチカチッ")
    try expectEq(OnomatopeMorphology.clickWord(approachSpeed: 3, pressDuration: 0.5, clickCount: 1), "グッ")
}

test("ドロップ: 放す速度で ポトッ→ポィ！→ポーイッ！、長運搬+静置=ドサッ") {
    try expectEq(OnomatopeMorphology.dropWord(releaseSpeed: 1, dragDuration: 1), "ポトッ")
    try expectEq(OnomatopeMorphology.dropWord(releaseSpeed: 8, dragDuration: 1), "ポィ！")
    try expectEq(OnomatopeMorphology.dropWord(releaseSpeed: 30, dragDuration: 1), "ポーイッ！")
    try expectEq(OnomatopeMorphology.dropWord(releaseSpeed: 1, dragDuration: 4), "ドサッ")
}

test("段差: 速度で コトッ→カタッ→ガタッ！、連続=ガタガタッ") {
    try expectEq(OnomatopeMorphology.edgeWord(speed: 4, recentCrossings: 1), "コトッ")
    try expectEq(OnomatopeMorphology.edgeWord(speed: 12, recentCrossings: 1), "カタッ")
    try expectEq(OnomatopeMorphology.edgeWord(speed: 30, recentCrossings: 1), "ガタッ！")
    try expectEq(OnomatopeMorphology.edgeWord(speed: 12, recentCrossings: 3), "ガタガタッ")
}

test("Enter: 打鍵速度で たん→ターン！→ッターン！→ッッターン！！") {
    try expectEq(OnomatopeMorphology.enterWord(typingRate: 0.5), "たん")
    try expectEq(OnomatopeMorphology.enterWord(typingRate: 3), "ターン！")
    try expectEq(OnomatopeMorphology.enterWord(typingRate: 6), "ッターン！")
    try expectEq(OnomatopeMorphology.enterWord(typingRate: 10), "ッッターン！！")
}

test("タイピング: 速度で ポチポチ→カチャカチャ→カタカタカタ→ダダダダッ") {
    try expectEq(OnomatopeMorphology.typingWord(rate: 1), "ポチポチ")
    try expectEq(OnomatopeMorphology.typingWord(rate: 4), "カチャカチャ")
    try expectEq(OnomatopeMorphology.typingWord(rate: 7), "カタカタカタ")
    try expectEq(OnomatopeMorphology.typingWord(rate: 12), "ダダダダッ")
}

test("右クリック: ためらい=ミギクリ…？ 通常=ミギクリッ！ 勢い=ミギバシッ！") {
    try expectEq(OnomatopeMorphology.rightClickWord(approachSpeed: 3, dwellBefore: 2.0), "ミギクリ…？")
    try expectEq(OnomatopeMorphology.rightClickWord(approachSpeed: 3, dwellBefore: 0.1), "ミギクリッ！")
    try expectEq(OnomatopeMorphology.rightClickWord(approachSpeed: 20, dwellBefore: 0.1), "ミギバシッ！")
}

// MARK: - θ→スタイル写像（Track B）

print("== θ→スタイル ==")

test("重い語は大きく暗く影が深い（θ→StyleParams）") {
    let heavy = StyleParams.from(theta: [0.9, 0.9, 0.0, 0.0])
    let light = StyleParams.from(theta: [0.1, 0.1, 0.0, 0.0])
    try expect(heavy.sizeScale > light.sizeScale, "重い方が大きい")
    try expect(heavy.shadowDepth > light.shadowDepth, "重い方が影が深い")
    try expect(heavy.brightness < light.brightness, "重い方が暗い")
    try expect(heavy.fontHeavy && !light.fontHeavy, "書体の重さ")
}

test("持続的な語にスピード線が付く") {
    try expect(StyleParams.from(theta: [0.3, 0.2, 0.9, 0]).speedLines > 0, "長音でスピード線")
    try expect(StyleParams.from(theta: [0.3, 0.2, 0.0, 0]).speedLines == 0, "非持続で0本")
}

// MARK: - 動作→θ写像

print("== 動作→θ潜在空間 ==")

test("速い動きは重い（voicing↑）・遅い動きは軽い") {
    var fast = MotionFeatures(); fast.speed = 28; fast.straight = 0.9
    var slow = MotionFeatures(); slow.speed = 2
    let tf = MotionToTheta.theta(from: fast)
    let ts = MotionToTheta.theta(from: slow)
    try expect(tf[0] > ts[0], "速い\(tf[0]) > 遅い\(ts[0])")
    try expect(tf[0] >= 0 && tf[0] <= 1, "範囲外")
}

test("ジャークが高いと鋭い（gemination↑）") {
    var sharp = MotionFeatures(); sharp.speed = 10; sharp.jerk = 8
    var smooth = MotionFeatures(); smooth.speed = 10; smooth.jerk = 0.5
    try expect(MotionToTheta.theta(from: sharp)[1] > MotionToTheta.theta(from: smooth)[1], "鋭さ")
}

test("反転・回転があると反復↑") {
    var rep = MotionFeatures(); rep.speed = 8; rep.flipX = 3; rep.flipY = 2
    var straight = MotionFeatures(); straight.speed = 8; straight.straight = 1
    try expect(MotionToTheta.theta(from: rep)[3] > MotionToTheta.theta(from: straight)[3], "反復")
}

// MARK: - OnomaFormer オンデバイス推論（Python参照一致）

print("== OnomaFormer（Swift推論） ==")

test("重みJSONをロードできる") {
    OnomaFormerCore.shared.load(from: URL(fileURLWithPath: "i18n/onomaformer.json"))
    try expect(OnomaFormerCore.shared.isReady, "ロード失敗")
}

test("生成レイテンシ: 1語あたり十分速い（ライブ表示可能）") {
    var rng = SystemRandomNumberGenerator()
    let start = Date()
    var n = 0
    for _ in 0..<20 {
        _ = OnomaFormerCore.shared.generate(theta: [0.5, 0.6, 0.3, 0.2], temperature: 1.0, rng: &rng)
        n += 1
    }
    let ms = Date().timeIntervalSince(start) / Double(n) * 1000
    print("    OnomaFormer生成: \(String(format: "%.1f", ms)) ms/語")
    try expect(ms < 60, "生成が遅すぎる: \(ms)ms")
}

test("θ条件が効く: 異なるθで妥当な語形を生成（再学習に頑健）") {
    var rng = SystemRandomNumberGenerator()
    let thetas: [[Double]] = [[0.9, 0.1, 0.0, 1.0], [0.5, 0.9, 0.6, 0.0], [0.1, 0.1, 0.0, 0.0]]
    var outs: [String] = []
    for th in thetas {
        guard let w = OnomaFormerCore.shared.generate(theta: th, temperature: 0.01, rng: &rng) else {
            throw AssertionError(description: "θ=\(th) 生成失敗")
        }
        try expect((2...8).contains(w.count), "不正な語形: \(w)")
        outs.append(w)
    }
    try expect(Set(outs).count >= 2, "θ条件が効いていない: \(outs)")
}

// MARK: - 中間語形生成器（C_F(θ)）

print("== 中間語形生成 ==")

test("クリック族: θでポチ→ポチッ→カチッ！→バチンッ！！と合成される") {
    try expectEq(MorphSynth.generate(family: "click", theta: [0.05, 0.1, 0, 0]), "ポチ")
    try expectEq(MorphSynth.generate(family: "click", theta: [0.1, 0.5, 0, 0]), "ポチッ")
    try expectEq(MorphSynth.generate(family: "click", theta: [0.5, 0.5, 0, 0]), "カチッ")
    try expectEq(MorphSynth.generate(family: "click", theta: [0.5, 0.7, 0, 0]), "カチッ！")
    try expectEq(MorphSynth.generate(family: "click", theta: [0.85, 0.95, 0, 0]), "バチンッ！！")
}

test("Enter族: 促音はprefix（ったん→ッドン！！）・最弱はかん") {
    try expectEq(MorphSynth.generate(family: "enter", theta: [0.05, 0.05, 0, 0]), "かん")
    try expectEq(MorphSynth.generate(family: "enter", theta: [0.25, 0.05, 0, 0]), "たん")
    try expectEq(MorphSynth.generate(family: "enter", theta: [0.7, 0.9, 0, 0]), "ッドン！！")
}

test("Enter族: そっと単発（v低・長音）で「かーん」") {
    try expectEq(MorphSynth.generate(family: "enter", theta: [0.05, 0.05, 0.6, 0]), "かーん")
}

test("打鍵族: 反復でポチポチ→カチャカチャ→カタカタ→ダダダダッ") {
    try expectEq(MorphSynth.generate(family: "typing", theta: [0.1, 0.2, 0, 1]), "ポチポチ")
    try expectEq(MorphSynth.generate(family: "typing", theta: [0.45, 0.4, 0, 1]), "カチャカチャ")
    try expectEq(MorphSynth.generate(family: "typing", theta: [0.65, 0.4, 0, 1]), "カタカタ")
    try expectEq(MorphSynth.generate(family: "typing", theta: [0.9, 0.7, 0, 1]), "ダダダダッ")
}

test("長音: elongation>0.5で先頭モーラ後にー（ポーイッ）") {
    try expectEq(MorphSynth.generate(family: "drop", theta: [0.4, 0.5, 0.7, 0]), "ポーイッ")
}

test("反復: reduplication>0.6で語幹重複（カチカチ/コトコト）") {
    try expectEq(MorphSynth.generate(family: "click", theta: [0.5, 0.2, 0, 0.8]), "カチカチ")
    try expectEq(MorphSynth.generate(family: "edge", theta: [0.1, 0.2, 0, 0.8]), "コトコト")
}

test("中間θ: 隣接段の中点が生成可能な語形になる") {
    guard let mid = MorphSynth.midTheta(family: "click", i: 1, j: 2) else {
        throw AssertionError(description: "midThetaがnil")
    }
    guard let form = MorphSynth.generate(family: "click", theta: mid) else {
        throw AssertionError(description: "生成失敗")
    }
    try expect(!form.isEmpty && form.count <= 8, "不正な語形: \(form)")
}

test("voicing単調性: θ1が上がると語幹ラダーが戻らない") {
    for (fam, spec) in MorphSynth.families {
        var lastIdx = -1
        for v in stride(from: 0.0, through: 1.0, by: 0.05) {
            guard let form = MorphSynth.generate(family: fam, theta: [v, 0, 0, 0]) else { continue }
            let idx = spec.stems.lastIndex(where: { form.hasPrefix($0.stem.prefix(1)) }) ?? 0
            try expect(idx >= lastIdx, "\(fam): v=\(v)でラダーが後退")
            lastIdx = max(lastIdx, idx)
        }
    }
}

// MARK: - 研究ログテスト

print("== 研究ログ ==")

func withTmpDir(_ body: (URL) throws -> Void) throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("onomatope-logger-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    try body(dir)
}

func readLines(_ url: URL) -> [String] {
    guard let s = try? String(contentsOf: url, encoding: .utf8) else { return [] }
    return s.split(separator: "\n").map(String.init)
}

test("デフォルトは無効・logはno-op") {
    try withTmpDir { dir in
        let logger = ResearchLogger(directory: dir)
        try expect(!logger.enabled, "初期状態で有効")
        logger.log(["x": 1])
        try expect(logger.currentFileURL == nil, "ファイルが作られた")
    }
}

test("start: metaが先頭行に書かれる") {
    try withTmpDir { dir in
        let logger = ResearchLogger(directory: dir)
        logger.start(meta: ["app_version": "test", "screen_w": 1920.0])
        try expect(logger.enabled, "startで有効にならない")
        guard let url = logger.currentFileURL else { throw AssertionError(description: "ログファイルが無い") }
        logger.stop()
        let lines = readLines(url)
        try expectEq(lines.count, 1)
        let meta = try JSONSerialization.jsonObject(with: lines[0].data(using: .utf8)!) as! [String: Any]
        try expectEq(meta["type"] as? String, "meta")
        try expectEq(meta["app_version"] as? String, "test")
        try expect(meta["ts"] != nil, "tsが無い")
    }
}

test("log→stop往復: 全行が正しいJSONL") {
    try withTmpDir { dir in
        let logger = ResearchLogger(directory: dir)
        logger.start(meta: ["app_version": "test"])
        for i in 0..<50 {
            logger.log(["ts": Double(i), "x": Double(i) * 1.5, "word": "スーッ", "fx": i % 3])
        }
        let url = logger.currentFileURL!
        logger.stop()
        let lines = readLines(url)
        try expectEq(lines.count, 51, "meta1行+50行")
        for l in lines {
            _ = try JSONSerialization.jsonObject(with: l.data(using: .utf8)!)
        }
        let rec = try JSONSerialization.jsonObject(with: lines[10].data(using: .utf8)!) as! [String: Any]
        try expectEq(rec["word"] as? String, "スーッ")
    }
}

test("時間ベースのフラッシュ: stopしなくても書かれる") {
    try withTmpDir { dir in
        var fakeNow: TimeInterval = 0
        let logger = ResearchLogger(directory: dir, flushInterval: 1.0, clock: { fakeNow })
        logger.start(meta: [:])
        let url = logger.currentFileURL!
        fakeNow = 0.5
        logger.log(["i": 1])
        fakeNow = 1.6
        logger.log(["i": 2])
        try expect(readLines(url).count >= 3, "時間フラッシュが動かない: \(readLines(url).count)行")
        logger.stop()
    }
}

test("stopで残バッファがフラッシュされる") {
    try withTmpDir { dir in
        let logger = ResearchLogger(directory: dir, flushInterval: 1000, clock: { 0 })
        logger.start(meta: [:])
        let url = logger.currentFileURL!
        for i in 0..<10 { logger.log(["i": i]) }
        logger.stop()
        try expectEq(readLines(url).count, 11)
    }
}

test("stop後のlogは書き込まれない") {
    try withTmpDir { dir in
        let logger = ResearchLogger(directory: dir)
        logger.start(meta: [:])
        let url = logger.currentFileURL!
        logger.stop()
        logger.log(["i": 99])
        logger.flush()
        try expectEq(readLines(url).count, 1)
    }
}

// MARK: - 筆のベクター変形（BrushDeform）

print("== 筆のベクター変形 ==")

test("筆圧変形: パスが変わるが極端に逸脱しない") {
    let r = CGPath(rect: CGRect(x: 0, y: 0, width: 40, height: 60), transform: nil)
    let poly = CGMutablePath()
    for k in 0..<12 {
        let a = CGFloat(k) / 12 * 2 * .pi
        let p = CGPoint(x: 30 + cos(a) * 25, y: 30 + sin(a) * 25)
        if k == 0 { poly.move(to: p) } else { poly.addLine(to: p) }
    }
    poly.closeSubpath()
    for path in [r, poly as CGPath] {
        let d = BrushDeform.apply(to: path, fontSize: 60, pressure: 0.8, taper: 0.8, seed: 1)
        try expect(!d.isEmpty, "変形パスが空")
        let bb0 = path.boundingBoxOfPath, bb1 = d.boundingBoxOfPath
        try expect(abs(bb1.midX - bb0.midX) < 20 && abs(bb1.midY - bb0.midY) < 20, "重心が飛んだ")
        try expect(bb1.width < bb0.width * 1.6 + 20, "幅が爆発: \(bb1.width)")
    }
}

test("筆圧0・テーパー0は恒等（同じパスを返す）") {
    let r = CGPath(rect: CGRect(x: 0, y: 0, width: 40, height: 60), transform: nil)
    let d = BrushDeform.apply(to: r, fontSize: 60, pressure: 0, taper: 0, seed: 1)
    try expect(d === r || d.boundingBoxOfPath == r.boundingBoxOfPath, "恒等でない")
}

test("かすれ筋: roughnessで本数が増え、決定的") {
    let bb = CGRect(x: 0, y: 0, width: 100, height: 60)
    let a = BrushDeform.scratchLines(bbox: bb, fontSize: 40, roughness: 0.2, seed: 3)
    let b = BrushDeform.scratchLines(bbox: bb, fontSize: 40, roughness: 0.9, seed: 3)
    let b2 = BrushDeform.scratchLines(bbox: bb, fontSize: 40, roughness: 0.9, seed: 3)
    try expect(b.count > a.count, "roughnessで増えない: \(a.count) vs \(b.count)")
    try expect(BrushDeform.scratchLines(bbox: bb, fontSize: 40, roughness: 0.01, seed: 3).isEmpty, "微小roughnessは空")
    try expectEq(b.count, b2.count)
    for (l1, l2) in zip(b, b2) {
        try expect(l1.from == l2.from && l1.to == l2.to && l1.width == l2.width, "非決定的")
    }
}

// MARK: - 族アンカー生成（FamilyGen）

print("== 族アンカー生成 ==")

test("シード選択: 打鍵はθ[0]でポチ→カタ→ダダのラダー") {
    try expectEq(FamilyGen.seed(family: "typing", theta: [0.1, 0.4, 0, 1]), "ポチ")
    try expectEq(FamilyGen.seed(family: "typing", theta: [0.65, 0.4, 0, 1]), "カタ")
    try expectEq(FamilyGen.seed(family: "typing", theta: [0.95, 0.4, 0, 1]), "ダダ")
}

test("シード選択: Enterのそっと単発（v低・e高）は「かー」") {
    try expectEq(FamilyGen.seed(family: "enter", theta: [0.1, 0.5, 0.6, 0]), "かー")
    try expectEq(FamilyGen.seed(family: "enter", theta: [0.5, 0.85, 0, 0]), "タン")
}

test("受理判定: 族の音色を守る語だけ通す") {
    try expect(FamilyGen.accepts(family: "typing", word: "カタカタッ"), "カタカタッは打鍵族")
    try expect(FamilyGen.accepts(family: "typing", word: "ガチャン！"), "ガチャン！は打鍵族")
    try expect(!FamilyGen.accepts(family: "typing", word: "ピョーン"), "ピョーンは打鍵族でない")
    try expect(!FamilyGen.accepts(family: "typing", word: "ふわふわ"), "ふわふわは打鍵族でない")
    try expect(FamilyGen.accepts(family: "enter", word: "ッターン！"), "ッターン！はEnter族")
    try expect(FamilyGen.accepts(family: "enter", word: "かーん"), "かーんはEnter族")
    try expect(!FamilyGen.accepts(family: "enter", word: "グニャ"), "グニャはEnter族でない")
}

test("族アンカー生成: 実モデルでも打鍵族は必ずカタカタ系（50連発）") {
    var rng = SystemRandomNumberGenerator()
    for i in 0..<50 {
        let th = [Double(i % 10) / 9.0, 0.4, 0, 1.0]
        guard let w = FamilyGen.generate(family: "typing", theta: th,
                                         cats: [1, 0, 0, 0, 0, 0], rng: &rng) else {
            throw AssertionError(description: "生成失敗 θ=\(th)")
        }
        try expect(FamilyGen.accepts(family: "typing", word: w) || MorphSynth.generate(family: "typing", theta: th) == w,
                   "族外の語: \(w) θ=\(th)")
    }
}

test("族アンカー生成: Enter族も同様（30連発・かーん経路含む）") {
    var rng = SystemRandomNumberGenerator()
    for i in 0..<30 {
        let th = [Double(i % 10) / 9.0, i % 3 == 0 ? 0.5 : 0.85, i % 4 == 0 ? 0.6 : 0, 0]
        guard let w = FamilyGen.generate(family: "enter", theta: th, rng: &rng) else {
            throw AssertionError(description: "生成失敗 θ=\(th)")
        }
        try expect(FamilyGen.accepts(family: "enter", word: w) || MorphSynth.generate(family: "enter", theta: th) == w,
                   "族外の語: \(w) θ=\(th)")
    }
}

test("シード生成の境界: 高温・長シードでも範囲外クラッシュしない（回帰: pos超過）") {
    guard OnomaFormerCore.shared.isReady else { return }
    var rng = SystemRandomNumberGenerator()
    for i in 0..<300 {
        let seed = ["カチャ", "ガタガタ", "ポチポチ", "ダダダダ"][i % 4]
        _ = OnomaFormerCore.shared.generate(theta: [0.5, 0.5, 0.5, 0.5],
                                            temperature: 2.0,   // eosが出にくい=最長生成になりやすい
                                            seed: seed, rng: &rng)
    }
    try expect(true, "ここまで来ればクラッシュなし")
}

test("OnomaFormerシード強制: 語頭がシードで始まる") {
    guard OnomaFormerCore.shared.isReady else { return }   // モデル未ロード環境はスキップ
    var rng = SystemRandomNumberGenerator()
    var seeded = 0
    for _ in 0..<20 {
        if let w = OnomaFormerCore.shared.generate(theta: [0.6, 0.4, 0, 1], cats: [1, 0, 0, 0, 0, 0],
                                                   temperature: 0.9, seed: "カタ", rng: &rng) {
            try expect(w.hasPrefix("カタ"), "シード無視: \(w)")
            seeded += 1
        }
    }
    try expect(seeded > 0, "シード生成が一度も成功しない")
}

// MARK: - 学習済みスタイル写像（StyleMap）

print("== StyleMap ==")

test("stylemap.jsonのロード・Δ適用・クランプ") {
    try withTmpDir { dir in
        let url = dir.appendingPathComponent("stylemap.json")
        let json: [String: Any] = [
            "delta": ["sizeScale": [0.5, 0.0, 0.0, 0.0, 0.0],   // 定数+0.5
                      "halo": [9.9, 0.0, 0.0, 0.0, 0.0],        // 範囲外に飛ぶ→クランプ
                      "bad": [1.0, 2.0]],                        // 5要素でない→無視
            "ranges": ["sizeScale": [0.5, 2.2], "halo": [0, 1]],
        ]
        try JSONSerialization.data(withJSONObject: json).write(to: url)
        let sm = StyleMap()
        sm.load(from: url)
        try expect(sm.isLoaded, "ロード失敗")
        try expectEq(sm.adjust("sizeScale", base: 1.0, theta: [0, 0, 0, 0]), 1.5)
        try expectEq(sm.adjust("halo", base: 0.5, theta: [0, 0, 0, 0]), 1.0, "クランプされるべき")
        try expectEq(sm.adjust("bad", base: 0.3, theta: [0, 0, 0, 0]), 0.3, "不正Δは素通し")
        try expectEq(sm.adjust("unknown", base: 0.7, theta: [0, 0, 0, 0]), 0.7, "未学習は素通し")
    }
}

test("stylemap未ロードは常に素通し（h0のまま）") {
    let sm = StyleMap()
    try expect(!sm.isLoaded, "未ロードのはず")
    try expectEq(sm.adjust("sizeScale", base: 1.23, theta: [0.5, 0.5, 0, 0]), 1.23)
}

test("θ依存Δ: [1,v,g,e,r]の内積が効く") {
    try withTmpDir { dir in
        let url = dir.appendingPathComponent("stylemap.json")
        let json: [String: Any] = ["delta": ["tilt": [0.0, 1.0, 0.0, 0.0, 0.0]],
                                   "ranges": ["tilt": [-0.4, 0.4]]]
        try JSONSerialization.data(withJSONObject: json).write(to: url)
        let sm = StyleMap()
        sm.load(from: url)
        try expectEq(sm.adjust("tilt", base: 0, theta: [0.3, 0, 0, 0]), 0.3)
        try expectEq(sm.adjust("tilt", base: 0, theta: [0.9, 0, 0, 0]), 0.4, "上限クランプ")
    }
}

// MARK: - 公開準備の追加テスト

print("== 公開準備 ==")

test("スクロール族: スル→シュル→ズルのラダー") {
    try expectEq(MorphSynth.generate(family: "scroll", theta: [0.1, 0.2, 0, 0]), "スル")
    try expectEq(MorphSynth.generate(family: "scroll", theta: [0.5, 0.2, 0, 0]), "シュル")
    try expectEq(MorphSynth.generate(family: "scroll", theta: [0.9, 0.2, 0, 0]), "ズル")
}

test("未知の族はnil（クラッシュしない）") {
    try expect(MorphSynth.generate(family: "nosuch", theta: [0.5, 0.5, 0, 0]) == nil, "nilのはず")
    try expect(FamilyGen.seed(family: "nosuch", theta: [0.5, 0.5, 0, 0]) == nil, "nilのはず")
    try expect(!FamilyGen.accepts(family: "nosuch", word: "カタ"), "falseのはず")
}

test("OnomaFormer: 語彙外文字のシードはnil（フォールバックに落ちる）") {
    guard OnomaFormerCore.shared.isReady else { return }
    var rng = SystemRandomNumberGenerator()
    let w = OnomaFormerCore.shared.generate(theta: [0.5, 0.5, 0, 0], seed: "ABC🦆", rng: &rng)
    try expect(w == nil, "語彙外シードはnilのはず: \(w ?? "nil")")
}

test("受理判定の境界: 長すぎ・短すぎは弾く") {
    try expect(!FamilyGen.accepts(family: "typing", word: "カ"), "1文字は短すぎ")
    try expect(!FamilyGen.accepts(family: "typing", word: "カタカタカタカタカ"), "9文字は長すぎ")
    try expect(FamilyGen.accepts(family: "typing", word: "カタ"), "2文字はOK")
}

// MARK: - Version（アップデート確認の比較器）

test("Version: 基本の大小と同値") {
    try expect(Version.isNewer("1.28.0", than: "1.27.0"), "パッチ上がりは新しい")
    try expect(!Version.isNewer("1.27.0", than: "1.27.0"), "同値は新しくない")
    try expect(!Version.isNewer("1.26.9", than: "1.27.0"), "古い方は新しくない")
    try expect(Version.isNewer("2.0.0", than: "1.99.99"), "メジャー優先")
}

test("Version: 桁数差・v接頭辞・数値比較") {
    try expect(Version.isNewer("1.10.0", than: "1.9.0"), "1.10 > 1.9（文字列比較でない）")
    try expect(Version.isNewer("v1.28.0", than: "1.27.5"), "v接頭辞を無視")
    try expect(Version.isNewer("1.28", than: "1.27.9"), "桁数が違っても比較できる")
    try expect(!Version.isNewer("", than: "0.0.1"), "空文字列は新しくない")
}

// MARK: - 結果

print("\n\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)

// 接地ログ（grounding.jsonl）— 動作とオノマトペのペアを教師データ化する土台
//
// 「マウス/キーボードの動き → オノマトペ」を学習するには、実際の動作と語のペアが要る。
// 本ログは (動作特徴, θ, 語, source) を記録する。sourceで教師の質が分かる:
//   shown     : ルール分類器が表示した語（弱教師・大量）
//   hud_gen   : 潜在HUDの未命名地帯でOnomaFormerが生成した語（探索・要検証）
//   summon    : 召喚チャレンジで人間が「その語のために作った」動作（最強の正例）
//   pair/reject: 選好・否定（別途feedback.jsonl。ここでは接地の起点のみ）
//
// これが train_motion_theta.py（動作→θ回帰）と OnomaFormer追加学習の入力になる。
import Foundation
import OnomatopeCore

enum GroundingLog {
    static let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("OnomatopeCursor/grounding.jsonl")

    private static var lastShownAt: TimeInterval = 0

    static func record(word: String, theta: [Double], source: String, features: [String: Double]) {
        var rec: [String: Any] = [
            "ts": Date().timeIntervalSince1970,
            "word": word, "theta": theta, "source": source,
            "lang": VocabularyStore.shared.currentLang,
        ]
        for (k, v) in features { rec[k] = v }
        append(rec)
        Uploader.shared.enqueueEvent(type: "grounding", payload: rec)
    }

    /// 表示語の接地（sourceが多いのでレート制限：2秒に1回）
    static func recordShown(word: String, features: [String: Double]) {
        let now = Date().timeIntervalSince1970
        guard now - lastShownAt > 2.0 else { return }
        lastShownAt = now
        record(word: word, theta: MotionThetaBridge.theta(features), source: "shown", features: features)
    }

    private static func append(_ rec: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: rec) else { return }
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile(); h.write(data); h.write(Data([0x0A])); try? h.close()
        }
    }
}

/// features辞書 → θ（MotionToThetaのdict版アダプタ）
enum MotionThetaBridge {
    static func theta(_ f: [String: Double]) -> [Double] {
        var mf = MotionFeatures()
        mf.speed = CGFloat(f["speed"] ?? 0)
        mf.jerk = CGFloat(f["jerk"] ?? 0)
        mf.cumTurn = CGFloat(f["turn"] ?? 0)
        mf.straight = CGFloat(f["straight"] ?? 0)
        return MotionToTheta.theta(from: mf)
    }
}

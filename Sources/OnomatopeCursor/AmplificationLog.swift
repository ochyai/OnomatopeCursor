// 増幅ログ — 「語が行為の感覚を増幅したか」を暗黙・自動で測る
//
// これがマルチモーダル増幅装置の中核データ。ユーザーに何も聞かず、行為の継続ダイナミクスから
// 暗黙の報酬を得る:
//   語が出た瞬間の行為強度(pre) と、直後0.8秒の行為強度(post) を比べる。
//   post > pre なら「語が行為を増幅した」（打鍵が速くなった/カーソルが勢いづいた）。
//   Δ = post/pre - 1 が増幅スコア。これを (語, θ, チャネル, Δ) で記録する。
//
// 集まると: どのオノマトペがどの行為をどれだけ増幅するかの地図ができ、OnomaFormerを
// 「一致」でなく「増幅」に向けて強化学習できる。使うだけで貯まる＝自動で研究が進む。
import Foundation
import QuartzCore
import OnomatopeCore

final class AmplificationLog {
    static let shared = AmplificationLog()

    static let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("OnomatopeCursor/amplification.jsonl")

    private struct Pending {
        let word: String
        let theta: [Double]
        let channel: String
        let preIntensity: Double
        let onset: CFTimeInterval
        var postPeak: Double
    }
    private var pending: Pending?

    /// 語が出た瞬間に呼ぶ（現在の行為強度を pre として記録開始）
    func onWord(_ word: String, theta: [Double], channel: String, intensity: Double) {
        // 直前の計測を確定してから新規開始
        finalizeIfDue(now: CACurrentMediaTime())
        guard intensity > 0.05 else { pending = nil; return }   // ほぼ静止なら増幅計測しない
        pending = Pending(word: word, theta: theta, channel: channel,
                          preIntensity: intensity, onset: CACurrentMediaTime(), postPeak: intensity)
    }

    /// 毎フレーム現在の行為強度を流す（post窓のピークを追う）
    func tick(intensity: Double) {
        guard var p = pending else { return }
        let now = CACurrentMediaTime()
        if now - p.onset <= 0.8 {
            p.postPeak = max(p.postPeak, intensity)
            pending = p
        } else {
            finalizeIfDue(now: now)
        }
    }

    private func finalizeIfDue(now: CFTimeInterval) {
        guard let p = pending, now - p.onset > 0.8 else { return }
        pending = nil
        let delta = p.preIntensity > 0.01 ? p.postPeak / p.preIntensity - 1 : 0
        let rec: [String: Any] = [
            "ts": Date().timeIntervalSince1970,
            "word": p.word, "theta": p.theta, "channel": p.channel,
            "pre": (p.preIntensity * 1000).rounded() / 1000,
            "post": (p.postPeak * 1000).rounded() / 1000,
            "amp": (delta * 1000).rounded() / 1000,   // 増幅スコア（>0=増幅、<0=減衰）
            "lang": VocabularyStore.shared.currentLang,
        ]
        append(rec)
        Uploader.shared.enqueueEvent(type: "amp", payload: rec)
    }

    private func append(_ rec: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: rec) else { return }
        let dir = Self.url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: Self.url.path) {
            FileManager.default.createFile(atPath: Self.url.path, contents: nil)
        }
        if let h = try? FileHandle(forWritingTo: Self.url) {
            h.seekToEndOfFile(); h.write(data); h.write(Data([0x0A])); try? h.close()
        }
    }
}

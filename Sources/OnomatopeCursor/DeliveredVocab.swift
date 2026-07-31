// 語彙のOTA配信＋貢献ポイントによるアンロック
//
// - Supabase公開バケットの feed.json を起動時＋24時間ごとに受信（データ提供ON時のみ通信）
// - 貢献ポイント（クイズ回答+5/チガウチガウ+3/図鑑新捕獲+2/クイズtimeout+1）でティアが解放され、
//   配信語がアイドルプールと図鑑に加わる——貢献すると語彙が増える
// - 将来: 夜間の新語自動生成（PLAN-AUTOMATION Track A4）→人間承認→このフィードへ
import Cocoa
import OnomatopeCore

final class DeliveredVocab {
    static let shared = DeliveredVocab()

    static let feedURL = URL(string: "https://qmywgdlnpkofukfhmegn.supabase.co/storage/v1/object/public/vocab/feed.json")!

    private let cacheURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("OnomatopeCursor/vocab-feed.json")

    struct DeliveredWord {
        let key: String          // canonical（日本語形）
        let family: String       // "idle" など
        let animName: String
        let size: CGFloat
        let colorHex: String
        let isState: Bool
        let forms: [String: (form: String, theta: [Double])]
    }

    private(set) var tiers: [(threshold: Int, words: [String])] = []
    private(set) var words: [String: DeliveredWord] = [:]

    // ── 貢献ポイント ──

    static var points: Int {
        get { UserDefaults.standard.integer(forKey: "contribPoints") }
        set { UserDefaults.standard.set(newValue, forKey: "contribPoints") }
    }

    static func addPoints(_ n: Int) { points += n }

    func unlockedWords() -> [String] {
        let p = Self.points
        return tiers.filter { p >= $0.threshold }.flatMap { $0.words }.filter { words[$0] != nil }
    }

    func lockedTiers() -> [(threshold: Int, words: [String])] {
        let p = Self.points
        return tiers.filter { p < $0.threshold }
    }

    /// アイドルプールに加える解放済み語（状態語抑制も考慮）
    func unlockedIdleWords(suppressState: Bool) -> [String] {
        unlockedWords().filter { key in
            guard let w = words[key], w.family == "idle" else { return false }
            return !(suppressState && w.isState)
        }
    }

    // ── スタイル解決（配信語はSTYLES非登録なのでここから合成） ──

    private static let animMap: [String: Anim] = [
        "iki": .iki, "jiwa": .jiwa, "sowa": .sowa, "moji": .moji, "boo": .boo,
        "uto": .uto, "muzu": .muzu, "soro": .soro, "puru": .puru, "sui": .sui, "kuru": .kuru,
    ]

    func style(for key: String) -> WordStyle? {
        guard let w = words[key] else { return nil }
        let anim = Self.animMap[w.animName] ?? .jiwa
        var color = NSColor(white: 0.85, alpha: 1)
        if w.colorHex.hasPrefix("#"), w.colorHex.count == 7,
           let v = UInt32(w.colorHex.dropFirst(), radix: 16) {
            color = NSColor(red: CGFloat((v >> 16) & 0xFF) / 255,
                            green: CGFloat((v >> 8) & 0xFF) / 255,
                            blue: CGFloat(v & 0xFF) / 255, alpha: 1)
        }
        return WordStyle(text: key, fontNames: MINCHO, size: w.size, color: color, anim: anim)
    }

    /// 配信語のローカライズ（VocabularyStoreの前段）
    func localize(_ key: String, lang: String) -> String? {
        words[key]?.forms[lang]?.form
    }

    // ── フィード受信 ──

    func loadCache() {
        if let data = try? Data(contentsOf: cacheURL) { parse(data) }
    }

    func fetch() {
        guard Uploader.shared.consent else { return }   // 通信はデータ提供同意の範囲内
        let last = UserDefaults.standard.double(forKey: "vocabFeedFetchedAt")
        guard Date().timeIntervalSince1970 - last > 3600 else { return }
        URLSession.shared.dataTask(with: Self.feedURL) { [weak self] data, resp, _ in
            guard let self, let data,
                  let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return }
            DispatchQueue.main.async {
                self.parse(data)
                try? FileManager.default.createDirectory(
                    at: self.cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? data.write(to: self.cacheURL)
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "vocabFeedFetchedAt")
            }
        }.resume()
    }

    private func parse(_ data: Data) {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tiersArr = obj["tiers"] as? [[String: Any]],
              let wordsObj = obj["words"] as? [String: [String: Any]] else { return }
        tiers = tiersArr.compactMap { t in
            guard let th = t["threshold"] as? Int, let ws = t["words"] as? [String] else { return nil }
            return (th, ws)
        }
        var out: [String: DeliveredWord] = [:]
        for (key, w) in wordsObj {
            guard let family = w["family"] as? String,
                  let formsObj = w["forms"] as? [String: [String: Any]] else { continue }
            var forms: [String: (String, [Double])] = [:]
            for (lang, f) in formsObj {
                if let form = f["form"] as? String, let theta = f["theta"] as? [Double] {
                    forms[lang] = (form, theta)
                }
            }
            out[key] = DeliveredWord(
                key: key, family: family,
                animName: w["anim"] as? String ?? "jiwa",
                size: CGFloat(w["size"] as? Double ?? 22),
                colorHex: w["color"] as? String ?? "#d8d8e0",
                isState: w["state"] as? Bool ?? false,
                forms: forms)
        }
        words = out
    }
}

// オノマトペ図鑑 — 出した語形をコレクションするミニゲーム
// 「初めて出せた語」が登録されていく。全語形コンプが目標＝多様な動きの内発的動機。
// データはローカル zukan.json、提供モードON時は捕獲イベントを送信。
import Cocoa
import OnomatopeCore

final class Zukan {
    static let shared = Zukan()

    private let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("OnomatopeCursor/zukan.json")

    private(set) var entries: [String: [String: Any]] = [:]   // word: {first: ts, count: n}

    init() {
        if let data = try? Data(contentsOf: url),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] {
            entries = obj
        }
    }

    /// 語の表示を記録。初捕獲ならtrue
    @discardableResult
    func record(_ word: String) -> Bool {
        guard word != "チガウチガウ" else { return false }
        let isNew = entries[word] == nil
        var e = entries[word] ?? ["first": Date().timeIntervalSince1970, "count": 0]
        e["count"] = (e["count"] as? Int ?? 0) + 1
        entries[word] = e
        save()
        if isNew {
            Uploader.shared.enqueueEvent(type: "capture",
                                         payload: ["word": word, "lang": VocabularyStore.shared.currentLang])
            DeliveredVocab.addPoints(2)
        }
        return isNew
    }

    private func save() {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        if let data = try? JSONSerialization.data(withJSONObject: entries) {
            try? data.write(to: url)
        }
    }

    // ── 図鑑ウィンドウ ──

    private var window: NSWindow?

    /// 図鑑の全対象（族ごと）
    static let families: [(String, [String])] = [
        ("運動", ["キョロキョロ", "オロオロ", "ソロソロ", "ジリジリ", "グルグル", "クルクル", "ビューン",
                 "ピタッ!!", "プルプル", "スーッ", "スイスイ", "ブンブン", "ピョンピョン", "ダダダッ", "ウロウロ"]),
        ("静止", ["すぅすぅ", "じわじわ", "そわそわ", "もじもじ", "ビクビクッ", "ウトウト", "ぼー…", "ムズムズ"]),
        ("クリック", ["ポチ", "ポチッ", "カチッ", "バチンッ", "グッ", "カチカチッ",
                    "ミギクリ…？", "ミギクリッ！", "ミギバシッ！"]),
        ("ドラッグ＆ドロップ", ["グイグイ", "ズルズル", "ポトッ", "ポィ！", "ポーイッ！", "ドサッ"]),
        ("キーボード", ["ポチポチ", "カチャカチャ", "カタカタカタ", "ダダダダッ",
                     "たん", "ターン！", "ッターン！", "ッッターン！！"]),
        ("トラックパッド", ["スルスル", "ガーッ", "シュルシュル", "シャッ", "ガバーッ", "キュッ", "グリグリ"]),
        ("段差", ["コトッ", "カタッ", "ガタッ！", "ガタガタッ"]),
        ("背景", ["フムフム", "ジロジロ", "ドキドキ"]),
    ]

    func showWindow() {
        let total = Self.families.reduce(0) { $0 + $1.1.count }
        let got = Self.families.reduce(0) { acc, fam in
            acc + fam.1.filter { entries[$0] != nil }.count
        }

        var text = "オノマトペ図鑑  \(got) / \(total)\n"
        text += "貢献ポイント: \(DeliveredVocab.points) pt\n"
        text += String(repeating: "━", count: 24) + "\n\n"
        for (name, words) in Self.families {
            let famGot = words.filter { entries[$0] != nil }.count
            text += "◆ \(name)（\(famGot)/\(words.count)）\n"
            for w in words {
                if let e = entries[w] {
                    let count = e["count"] as? Int ?? 0
                    text += "  \(w)  ×\(count)\n"
                } else {
                    text += "  ？？？\n"
                }
            }
            text += "\n"
        }
        // 配信語（貢献で解放）
        let unlocked = DeliveredVocab.shared.unlockedWords()
        let lockedTiers = DeliveredVocab.shared.lockedTiers()
        if !unlocked.isEmpty || !lockedTiers.isEmpty {
            text += "◆ 配信（貢献で解放）\n"
            for w in unlocked {
                if let e = entries[w] {
                    text += "  \(w)  ×\(e["count"] as? Int ?? 0)\n"
                } else {
                    text += "  \(w)  （解放済・未遭遇）\n"
                }
            }
            for tier in lockedTiers {
                let need = tier.threshold - DeliveredVocab.points
                text += "  🔒 \(tier.words.count)語  あと\(need)pt で解放\n"
            }
            text += "\n"
        }
        if got == total {
            text += "🏆 コンプリート！ あなたの身体は全語彙を話せます\n"
        }

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 340, height: 560))
        let tv = NSTextView(frame: scroll.bounds)
        tv.isEditable = false
        tv.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        tv.string = text
        tv.textContainerInset = NSSize(width: 16, height: 16)
        scroll.documentView = tv
        scroll.hasVerticalScroller = true

        let win = window ?? NSWindow(contentRect: scroll.frame,
                                     styleMask: [.titled, .closable, .resizable],
                                     backing: .buffered, defer: false)
        win.title = "オノマトペ図鑑"
        win.contentView = scroll
        win.isReleasedWhenClosed = false
        window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

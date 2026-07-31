// 召喚チャレンジ（ゲーム版）— お題の語を動きで出す
//
// 事務的なダイアログをやめ、大きな絵文字カード＋ヒント＋ライブ判定＋成功演出で
// 「思わずその動きをしたくなる」体験にする。成功=(動作→語)の最強正例を接地記録。
import Cocoa
import OnomatopeCore

final class SummonGame {
    static let shared = SummonGame()

    struct Quest { let word: String; let emoji: String; let hint: String }
    static let quests: [Quest] = [
        Quest(word: "キョロキョロ", emoji: "👀", hint: "左右に すばやく 見回して"),
        Quest(word: "グルグル", emoji: "🌀", hint: "ぐるぐる 円を描いて"),
        Quest(word: "ビューン", emoji: "💨", hint: "まっすぐ 高速で ひとっ飛び！"),
        Quest(word: "プルプル", emoji: "🫨", hint: "その場で 小刻みに ふるわせて"),
        Quest(word: "ソロソロ", emoji: "🐌", hint: "そーっと ゆっくり 慎重に"),
        Quest(word: "ピョンピョン", emoji: "🐰", hint: "上下に ぴょんぴょん 跳ねて"),
        Quest(word: "ウロウロ", emoji: "🚶", hint: "あてもなく ウロウロ さまよって"),
        Quest(word: "ダダダッ", emoji: "🏃", hint: "速く 荒々しく 走らせて"),
        Quest(word: "スイスイ", emoji: "🐟", hint: "なめらかに 泳ぐように"),
        Quest(word: "ブンブン", emoji: "🐝", hint: "激しく 左右に 振り回して"),
    ]

    private var panel: NSPanel?
    private let view = GameView()
    private(set) var target: String?
    private var streak = 0

    var isActive: Bool { panel != nil }

    func start() {
        if panel == nil { makePanel() }
        nextRound()
        NSApp.activate(ignoringOtherApps: true)
    }

    func stop() {
        panel?.close(); panel = nil; target = nil
    }

    private func makePanel() {
        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 300),
                        styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
                        backing: .buffered, defer: false)
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.isMovableByWindowBackground = true
        p.level = .floating
        p.isFloatingPanel = true
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        p.backgroundColor = NSColor(white: 0.08, alpha: 0.97)
        view.frame = NSRect(x: 0, y: 0, width: 360, height: 300)
        view.onNext = { [weak self] in self?.nextRound() }
        view.onClose = { [weak self] in self?.stop() }
        p.contentView = view
        // 画面右上に配置
        if let scr = NSScreen.main {
            p.setFrameOrigin(NSPoint(x: scr.visibleFrame.maxX - 380, y: scr.visibleFrame.maxY - 320))
        }
        p.orderFrontRegardless()
        panel = p
    }

    private func nextRound() {
        let q = Self.quests.randomElement()!
        target = q.word
        view.setQuest(q, streak: streak)
    }

    /// tickから毎フレーム呼ぶ。現在語が目標なら成功
    func update(currentWord: String, features: [String: Double], theta: [Double]) {
        guard let t = target, isActive else { return }
        view.setLive(current: currentWord, target: t)
        if currentWord == t {
            target = nil
            streak += 1
            DeliveredVocab.addPoints(8)
            GroundingLog.record(word: t, theta: theta, source: "summon", features: features)
            view.celebrate(word: t, streak: streak)
        }
    }
}

private final class GameView: NSView {
    var onNext: (() -> Void)?
    var onClose: (() -> Void)?

    private let emojiLabel = NSTextField(labelWithString: "")
    private let wordLabel = NSTextField(labelWithString: "")
    private let hintLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let nextButton = NSButton(title: "つぎのお題 →", target: nil, action: nil)
    private var celebrating = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true

        let title = NSTextField(labelWithString: "🎯 召喚チャレンジ")
        title.font = .systemFont(ofSize: 13, weight: .bold)
        title.textColor = NSColor(white: 0.7, alpha: 1)
        title.frame = NSRect(x: 0, y: 262, width: 360, height: 22)
        title.alignment = .center
        addSubview(title)

        emojiLabel.font = .systemFont(ofSize: 84)
        emojiLabel.frame = NSRect(x: 0, y: 150, width: 360, height: 100)
        emojiLabel.alignment = .center
        addSubview(emojiLabel)

        wordLabel.font = .systemFont(ofSize: 40, weight: .heavy)
        wordLabel.frame = NSRect(x: 0, y: 96, width: 360, height: 56)
        wordLabel.alignment = .center
        addSubview(wordLabel)

        hintLabel.font = .systemFont(ofSize: 15, weight: .medium)
        hintLabel.textColor = NSColor(white: 0.75, alpha: 1)
        hintLabel.frame = NSRect(x: 20, y: 66, width: 320, height: 24)
        hintLabel.alignment = .center
        addSubview(hintLabel)

        statusLabel.font = .systemFont(ofSize: 16, weight: .bold)
        statusLabel.frame = NSRect(x: 20, y: 38, width: 320, height: 24)
        statusLabel.alignment = .center
        addSubview(statusLabel)

        nextButton.bezelStyle = .rounded
        nextButton.frame = NSRect(x: 110, y: 8, width: 140, height: 28)
        nextButton.target = self
        nextButton.action = #selector(next)
        addSubview(nextButton)

        let close = NSButton(title: "✕", target: self, action: #selector(closeGame))
        close.isBordered = false
        close.frame = NSRect(x: 326, y: 262, width: 28, height: 22)
        addSubview(close)
    }
    required init?(coder: NSCoder) { nil }

    func setQuest(_ q: SummonGame.Quest, streak: Int) {
        celebrating = false
        emojiLabel.stringValue = q.emoji
        wordLabel.stringValue = q.word
        wordLabel.textColor = .white
        hintLabel.stringValue = q.hint
        hintLabel.isHidden = false
        statusLabel.stringValue = streak > 0 ? "\(streak)連続！ この動きを出せ" : "この動きを出せ！"
        statusLabel.textColor = NSColor(white: 0.6, alpha: 1)
        nextButton.title = "パス →"
    }

    func setLive(current: String, target: String) {
        guard !celebrating else { return }
        // 同じ勾配族・近縁なら「おしい！」
        if current == target { return }
        if !current.isEmpty && near(current, target) {
            statusLabel.stringValue = "おしい！ もう少し"
            statusLabel.textColor = .systemOrange
        } else {
            statusLabel.stringValue = "この動きを出せ！"
            statusLabel.textColor = NSColor(white: 0.6, alpha: 1)
        }
    }

    private func near(_ a: String, _ b: String) -> Bool {
        let groups = [["キョロキョロ", "ブンブン"], ["グルグル", "クルクル"],
                      ["ビューン", "ダダダッ", "スーッ", "スイスイ"], ["ソロソロ", "ジリジリ"],
                      ["プルプル", "オロオロ"], ["ピョンピョン"], ["ウロウロ"]]
        return groups.contains { $0.contains(a) && $0.contains(b) }
    }

    func celebrate(word: String, streak: Int) {
        celebrating = true
        emojiLabel.stringValue = "🎉"
        wordLabel.stringValue = "つかまえた！"
        wordLabel.textColor = .systemYellow
        hintLabel.stringValue = "「\(word)」ゲット！  +8pt"
        hintLabel.isHidden = false
        statusLabel.stringValue = "\(streak)連続 🔥  あなたの動きが学習データに"
        statusLabel.textColor = .systemGreen
        nextButton.title = "つぎのお題 →"

        // 軽い拡大アニメ
        wordLabel.layer?.removeAllAnimations()
        let a = CABasicAnimation(keyPath: "transform.scale")
        a.fromValue = 0.6; a.toValue = 1.0; a.duration = 0.35
        a.timingFunction = CAMediaTimingFunction(name: .easeOut)
        wordLabel.wantsLayer = true
        wordLabel.layer?.add(a, forKey: "pop")
    }

    @objc private func next() { onNext?() }
    @objc private func closeGame() { onClose?() }
}

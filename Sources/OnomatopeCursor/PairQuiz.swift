// 2択ミニゲーム「どっちが自然？」— 語形選好の収集（Bradley–Terry選好学習の実教師）
//
// イベント語（勾配族）の直後にだけ、カーソル脇に小さな非侵入パネルを出す。
// ワンクリック回答 / 6秒無視で消える（無回答も記録）。8分に1回まで。フォーカスは奪わない。
// 記録: (動作特徴, 族, formA, formB, choice, 反応時間) → feedback.jsonl + Supabase
import Cocoa
import OnomatopeCore

final class PairQuiz {
    static let shared = PairQuiz()

    var enabled = UserDefaults.standard.bool(forKey: "pairQuiz") {
        didSet { UserDefaults.standard.set(enabled, forKey: "pairQuiz") }
    }

    private var lastAsked: CFTimeInterval = -1e9
    private var panel: NSPanel?
    private var askedAt: CFTimeInterval = 0
    private var closeTimer: Timer?
    private var current: (family: String, first: String, second: String, features: [String: Double],
                          genTheta: [Double]?)?

    /// 勾配族（gentle→forceful順）
    static let gradients: [(family: String, forms: [String])] = [
        ("click", ["ポチ", "ポチッ", "カチッ", "バチンッ"]),
        ("enter", ["たん", "ターン！", "ッターン！", "ッッターン！！"]),
        ("drop", ["ポトッ", "ポィ！", "ポーイッ！", "ドサッ"]),
        ("edge", ["コトッ", "カタッ", "ガタッ！"]),
        ("rightclick", ["ミギクリ…？", "ミギクリッ！", "ミギバシッ！"]),
    ]

    static func familyOf(_ word: String) -> (String, [String], Int)? {
        for g in gradients {
            if let i = g.forms.firstIndex(of: word) { return (g.family, g.forms, i) }
        }
        return nil
    }

    /// イベント語の表示直後に呼ばれる。条件を満たせば1.2秒後にパネルを出す
    func maybeAsk(word: String, features: [String: Double]) {
        let now = CACurrentMediaTime()
        guard enabled, panel == nil, now - lastAsked > 480,
              let (family, forms, idx) = Self.familyOf(word) else { return }
        // 隣接語形とのペア（境界の精密化）
        let altIdx = idx == 0 ? 1 : (idx == forms.count - 1 ? forms.count - 2
                                     : (Bool.random() ? idx - 1 : idx + 1))
        var alt = forms[altIdx]
        var genTheta: [Double]? = nil
        // 35%: 生成語（中間θの合成語形）を対戦相手に——システムの仮説 vs 既存語
        if Double.random(in: 0..<1) < 0.35,
           let mid = MorphSynth.midTheta(family: family, i: idx, j: altIdx),
           let gen = MorphSynth.generate(family: family, theta: mid),
           gen != word, Self.familyOf(gen) == nil {   // 既存語形と衝突しない生成語のみ
            alt = gen
            genTheta = mid
        }
        let (first, second) = Bool.random() ? (word, alt) : (alt, word)
        lastAsked = now

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self, self.panel == nil else { return }
            self.present(family: family, first: first, second: second,
                         features: features, genTheta: genTheta)
        }
    }

    private func present(family: String, first: String, second: String,
                         features: [String: Double], genTheta: [Double]?) {
        current = (family, first, second, features, genTheta)
        askedAt = CACurrentMediaTime()

        let w: CGFloat = 280, h: CGFloat = 96
        let mouse = NSEvent.mouseLocation
        var origin = NSPoint(x: mouse.x + 24, y: mouse.y - h - 24)
        if let screen = NSScreen.main {
            origin.x = min(max(origin.x, screen.visibleFrame.minX + 8),
                           screen.visibleFrame.maxX - w - 8)
            origin.y = min(max(origin.y, screen.visibleFrame.minY + 8),
                           screen.visibleFrame.maxY - h - 8)
        }

        let p = NSPanel(contentRect: NSRect(origin: origin, size: NSSize(width: w, height: h)),
                        styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
                        backing: .buffered, defer: false)
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.isMovableByWindowBackground = true
        p.level = .floating
        p.becomesKeyOnlyIfNeeded = true
        p.isReleasedWhenClosed = false

        let content = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))

        let label = NSTextField(labelWithString: "どっちが自然？")
        label.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        label.frame = NSRect(x: 0, y: h - 30, width: w, height: 20)
        label.alignment = .center
        content.addSubview(label)

        let store = VocabularyStore.shared
        let btnA = NSButton(title: store.localize(first), target: self, action: #selector(chooseFirst))
        let btnB = NSButton(title: store.localize(second), target: self, action: #selector(chooseSecond))
        for (i, b) in [btnA, btnB].enumerated() {
            b.bezelStyle = .rounded
            b.font = NSFont.systemFont(ofSize: 14, weight: .bold)
            b.frame = NSRect(x: 14 + CGFloat(i) * (w / 2 - 7), y: 14, width: w / 2 - 21, height: 36)
            content.addSubview(b)
        }

        p.contentView = content
        p.orderFrontRegardless()
        panel = p

        // 6秒無視でtimeoutとして記録して閉じる
        closeTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: false) { [weak self] _ in
            self?.record(choice: "timeout")
        }
    }

    @objc private func chooseFirst() { record(choice: "first") }
    @objc private func chooseSecond() { record(choice: "second") }

    private func record(choice: String) {
        guard let cur = current else { return }
        let rt = CACurrentMediaTime() - askedAt
        var payload: [String: Any] = [
            "ts": Date().timeIntervalSince1970,
            "type": "pair",
            "family": cur.family,
            "a": cur.first, "b": cur.second,
            "choice": choice == "first" ? cur.first : (choice == "second" ? cur.second : "timeout"),
            "rt": (rt * 100).rounded() / 100,
            "lang": VocabularyStore.shared.currentLang,
        ]
        for (k, v) in cur.features { payload[k] = v }
        if let gt = cur.genTheta {
            payload["gen"] = true
            payload["gen_theta"] = gt
        }
        FeedbackLog.append(payload)
        Uploader.shared.enqueueEvent(type: "pair", payload: payload)
        DeliveredVocab.addPoints(choice == "timeout" ? 1 : 5)

        closeTimer?.invalidate()
        closeTimer = nil
        panel?.close()
        panel = nil
        current = nil
    }
}

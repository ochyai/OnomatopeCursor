// 多言語語彙パック（データ駆動・コードから分離）
//
// 設計の切り分け:
//   - canonical キー = 日本語語形（分類器・形態生成・スタイル表の内部ID。言語非依存に固定）
//   - 語彙データ = i18n/vocab-{lang}.json（各語形に θ=[voicing,gemination,elongation,reduplication] 注釈付き）
//     → 同じJSONがML形態パラメータ回帰の多言語教師データを兼ねる
//   - 表示直前（show()）でのみ canonical → 表示語形に解決する
import Foundation

public struct LocalizedForm: Codable {
    public let form: String
    public let theta: [Double]   // [voicing, gemination, elongation, reduplication] 各0-1
}

public struct LanguagePack: Codable {
    public let lang: String
    public let device_notes: String
    public let forms: [String: LocalizedForm]
}

public final class VocabularyStore {
    public static let shared = VocabularyStore()

    public private(set) var packs: [String: LanguagePack] = [:]
    public var currentLang: String = "ja"   // "ja"はcanonicalそのまま

    public init() {}

    /// i18nディレクトリの vocab-*.json を読み込む
    public func load(from dir: URL) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for url in files where url.lastPathComponent.hasPrefix("vocab-") && url.pathExtension == "json" {
            if let data = try? Data(contentsOf: url),
               let pack = try? JSONDecoder().decode(LanguagePack.self, from: data) {
                packs[pack.lang] = pack
            }
        }
    }

    public var availableLangs: [String] { ["ja"] + packs.keys.sorted() }

    /// canonical語形 → 現在言語の表示語形（ja・未収録はcanonicalのまま）
    public func localize(_ canonical: String) -> String {
        guard currentLang != "ja", let pack = packs[currentLang],
              let f = pack.forms[canonical] else { return canonical }
        return f.form
    }

    /// 現在言語でのθ（分析・強度連動の将来利用）
    public func theta(_ canonical: String) -> [Double]? {
        packs[currentLang]?.forms[canonical]?.theta
    }
}

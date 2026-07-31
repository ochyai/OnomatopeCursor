// データ提供（明示オプトイン）: Supabaseへの自動送信とオフラインキュー
//
// 設計:
//  - 送信は「データ提供に協力」ON時のみ。OFFなら本ファイルのネットワークコードは一切動かない
//  - 設定は ~/Library/Application Support/OnomatopeCursor/upload.json
//      {"url": "https://xxxx.supabase.co", "anon_key": "..."}
//    が置かれるまで送信せずローカルキューに貯める（後から差し替え可能なUploader抽象）
//  - 匿名ID: 初回起動時にUUID生成（氏名と紐付けない）
//  - サーバー側はinsert-only（scripts/setup_supabase.sql のRLS）
import Foundation
import Compression

final class Uploader {
    static let shared = Uploader()

    private let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("OnomatopeCursor", isDirectory: true)
    private var queueDir: URL { base.appendingPathComponent("upload-queue", isDirectory: true) }
    private var configURL: URL { base.appendingPathComponent("upload.json") }

    var consent: Bool = UserDefaults.standard.bool(forKey: "uploadConsent") {
        didSet { UserDefaults.standard.set(consent, forKey: "uploadConsent") }
    }

    let anonID: String = {
        if let id = UserDefaults.standard.string(forKey: "anonID") { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "anonID")
        return id
    }()

    struct Config { let url: String; let key: String }

    var config: Config? {
        // 手置きのupload.json（上書き用）→ アプリ同梱のupload-default.json の順。
        // 同梱により、配布リリースの協力者は同意ONだけでデータ提供が成立する
        // （anonキーはinsert-only RLS前提の公開可能キー。build.shが非git管理の
        //  packaging/upload-default.json をResourcesへ同梱する）
        if let c = Self.read(configURL) { return c }
        if let bundled = Bundle.main.url(forResource: "upload-default", withExtension: "json"),
           let c = Self.read(bundled) { return c }
        return nil
    }

    private static func read(_ url: URL) -> Config? {
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let u = obj["url"], let key = obj["anon_key"] else { return nil }
        return Config(url: u, key: key)
    }

    // ── キュー投入（同意ON時のみ。設定未投入でもキューには貯める） ──

    func enqueueEvent(type: String, payload: [String: Any]) {
        guard consent else { return }
        let rec: [String: Any] = ["anon_id": anonID, "ts": Date().timeIntervalSince1970,
                                  "type": type, "payload": payload]
        guard let data = try? JSONSerialization.data(withJSONObject: rec) else { return }
        try? FileManager.default.createDirectory(at: queueDir, withIntermediateDirectories: true)
        let name = "evt-\(Int(Date().timeIntervalSince1970 * 1000))-\(Int.random(in: 0..<9999)).json"
        try? data.write(to: queueDir.appendingPathComponent(name))
    }

    /// セッションログを圧縮してキューへ（研究ログOFF時に呼ばれる）
    func enqueueSessionFile(_ url: URL) {
        guard consent, let raw = try? Data(contentsOf: url), !raw.isEmpty else { return }
        try? FileManager.default.createDirectory(at: queueDir, withIntermediateDirectories: true)
        let gz = compress(raw)
        let name = "log-\(url.deletingPathExtension().lastPathComponent).jsonl.zlib"
        try? gz.write(to: queueDir.appendingPathComponent(name))
    }

    private func compress(_ data: Data) -> Data {
        var out = Data(count: data.count + 1024)
        let n = out.withUnsafeMutableBytes { dst in
            data.withUnsafeBytes { src in
                compression_encode_buffer(dst.bindMemory(to: UInt8.self).baseAddress!, dst.count,
                                          src.bindMemory(to: UInt8.self).baseAddress!, src.count,
                                          nil, COMPRESSION_ZLIB)
            }
        }
        return n > 0 ? out.prefix(n) : data
    }

    // ── 送信（5分ごと＋起動時にflush。失敗したらキューに残る） ──

    func flush() {
        guard consent, let cfg = config,
              let files = try? FileManager.default.contentsOfDirectory(at: queueDir, includingPropertiesForKeys: nil),
              !files.isEmpty else { return }

        for file in files.prefix(50) {
            let name = file.lastPathComponent
            var req: URLRequest
            if name.hasPrefix("evt-") {
                guard let body = try? Data(contentsOf: file) else { continue }
                var r = URLRequest(url: URL(string: "\(cfg.url)/rest/v1/events")!)
                r.httpMethod = "POST"
                r.httpBody = body
                r.setValue("application/json", forHTTPHeaderField: "Content-Type")
                r.setValue("return=minimal", forHTTPHeaderField: "Prefer")
                req = r
            } else {
                guard let body = try? Data(contentsOf: file) else { continue }
                let path = "logs/\(anonID)/\(name)"
                var r = URLRequest(url: URL(string: "\(cfg.url)/storage/v1/object/\(path)")!)
                r.httpMethod = "POST"
                r.httpBody = body
                r.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
                req = r
            }
            req.setValue(cfg.key, forHTTPHeaderField: "apikey")
            req.setValue("Bearer \(cfg.key)", forHTTPHeaderField: "Authorization")

            URLSession.shared.dataTask(with: req) { _, resp, _ in
                if let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                    try? FileManager.default.removeItem(at: file)
                }
            }.resume()
        }
    }
}

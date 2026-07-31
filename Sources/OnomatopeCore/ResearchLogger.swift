// 研究ログ（オプトイン・ローカル保存のみ・テスト可能）
import Foundation

public final class ResearchLogger {
    public private(set) var enabled = false
    public private(set) var currentFileURL: URL?
    private var handle: FileHandle?
    private var buffer = Data()
    private var lastFlush: TimeInterval = 0
    public let dirURL: URL
    private let clock: () -> TimeInterval
    private let flushInterval: TimeInterval

    public init(
        directory: URL? = nil,
        flushInterval: TimeInterval = 1.0,
        clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.dirURL = directory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("OnomatopeCursor/logs", isDirectory: true)
        self.flushInterval = flushInterval
        self.clock = clock
    }

    /// 記録開始。metaは先頭行に書かれる（app_version等）
    public func start(meta: [String: Any] = [:]) {
        try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmmss"
        df.locale = Locale(identifier: "en_US_POSIX")
        let url = dirURL.appendingPathComponent("session-\(df.string(from: Date())).jsonl")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        handle = try? FileHandle(forWritingTo: url)
        currentFileURL = handle != nil ? url : nil
        enabled = handle != nil
        var rec: [String: Any] = ["type": "meta", "ts": Date().timeIntervalSince1970]
        meta.forEach { rec[$0.key] = $0.value }
        log(rec)
        flush()
    }

    public func stop() {
        flush()
        try? handle?.close()
        handle = nil
        enabled = false
    }

    public func log(_ rec: [String: Any]) {
        guard enabled, let data = try? JSONSerialization.data(withJSONObject: rec) else { return }
        buffer.append(data)
        buffer.append(0x0A)
        // 時間ベースで書き込み（強制終了時の損失を最大 flushInterval 秒分に抑える）
        let now = clock()
        if now - lastFlush > flushInterval {
            flush()
            lastFlush = now
        }
    }

    public func flush() {
        guard let h = handle, !buffer.isEmpty else { return }
        do {
            try h.write(contentsOf: buffer)
            buffer.removeAll(keepingCapacity: true)
        } catch {
            // 書き込み失敗時はバッファを保持して次回に再試行
        }
    }
}

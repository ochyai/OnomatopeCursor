// アプリ更新の確認（研究協力者への配布用）
//
// 設計（ネットワークはOFF既定の方針を維持する）:
//  - 手動確認: メニュー「アップデートを確認…」→ ユーザー起点の通信なので常に可
//  - 自動確認: 24時間ごと。「データ提供に協力」ON時のみ（語彙フィードと同じゲート）
//  - appcast は語彙フィードと同じ公開バケット:
//      {"version": "1.28.0", "url": "https://github.com/...", "notes": "一言"}
//  - 送信するものは何もない（GETのみ・識別子なし）
import Cocoa
import OnomatopeCore

final class UpdateChecker {
    static let shared = UpdateChecker()

    static let appcastURL = URL(string:
        "https://qmywgdlnpkofukfhmegn.supabase.co/storage/v1/object/public/vocab/appcast.json")!

    struct Info { let version: String; let url: String; let notes: String }
    private(set) var available: Info?
    var onAvailable: ((Info) -> Void)?   // メニューに「⤓ 新版あり」を出すためのフック

    /// 自動確認（データ提供同意の範囲内・24時間に1回）
    func autoCheck() {
        guard Uploader.shared.consent else { return }
        let last = UserDefaults.standard.double(forKey: "updateCheckedAt")
        guard Date().timeIntervalSince1970 - last > 86_400 else { return }
        check { _ in }
    }

    /// 確認して結果をコールバック（nil=最新 or 取得失敗。手動時はUI側で出し分け）
    func check(completion: @escaping (Info?) -> Void) {
        var req = URLRequest(url: Self.appcastURL)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        URLSession.shared.dataTask(with: req) { [weak self] data, resp, _ in
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "updateCheckedAt")
            guard let self, let data,
                  let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ver = obj["version"] as? String,
                  let url = obj["url"] as? String else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let info = Info(version: ver, url: url, notes: obj["notes"] as? String ?? "")
            DispatchQueue.main.async {
                if Version.isNewer(ver, than: APP_VERSION) {
                    self.available = info
                    self.onAvailable?(info)
                    completion(info)
                } else {
                    completion(nil)
                }
            }
        }.resume()
    }
}

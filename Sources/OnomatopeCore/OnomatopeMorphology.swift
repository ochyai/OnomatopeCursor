// オノマトペ形態生成器 — 動作の質（マナー）から語形を連続的に選ぶ
//
// 日本語オノマトペの音象徴形態論:
//   濁音化 = 重さ・強さ（カタ→ガタ、ポト→ドサ） / 促音ッ = 鋭さ・急峻
//   長音ー = 持続・距離 / 反復 = 繰り返し
// イベントの種類は語の「族」を決め、動作の質が語の「形」を決める。
// このルール生成器はML形態パラメータ回帰（ml/README.md）の弱教師を兼ねる。
import Foundation
import CoreGraphics

public enum OnomatopeMorphology {

    /// クリック: 接近速度と押し込み方で揺らぐ
    public static func clickWord(approachSpeed: CGFloat, pressDuration: TimeInterval, clickCount: Int) -> String {
        if clickCount >= 2 { return "カチカチッ" }
        if pressDuration > 0.35 { return "グッ" }        // 押し込み続けている
        if approachSpeed > 18 { return "バチンッ" }       // 勢いよく飛んできて叩く（濁音=強打）
        if approachSpeed > 6 { return "カチッ" }          // きびきび
        if approachSpeed < 1.5 { return "ポチ" }          // そっと（促音なし=柔）
        return "ポチッ"
    }

    /// ドロップ: 放す瞬間の速度と運んだ時間で揺らぐ
    public static func dropWord(releaseSpeed: CGFloat, dragDuration: TimeInterval) -> String {
        if releaseSpeed > 20 { return "ポーイッ！" }      // 勢いよく放り投げる（長音=飛距離）
        if releaseSpeed < 2 { return dragDuration > 2.5 ? "ドサッ" : "ポトッ" }  // 静かに置く/重い荷を下ろす
        return "ポィ！"
    }

    /// 窓の段差: 通過速度と連続性で揺らぐ
    public static func edgeWord(speed: CGFloat, recentCrossings: Int) -> String {
        if recentCrossings >= 3 { return "ガタガタッ" }   // 反復=連続
        if speed > 22 { return "ガタッ！" }               // 濁音=強い衝撃
        if speed < 7 { return "コトッ" }                  // ゆっくりまたぐ
        return "カタッ"
    }

    /// 右クリック: ためらいと勢いで揺らぐ
    public static func rightClickWord(approachSpeed: CGFloat, dwellBefore: CGFloat) -> String {
        if dwellBefore > 1.2 { return "ミギクリ…？" }     // 迷ってから押す
        if approachSpeed > 15 { return "ミギバシッ！" }    // 勢いよく
        return "ミギクリッ！"
    }

    /// Enter: 直前の打鍵速度=勢いで揺らぐ
    public static func enterWord(typingRate: CGFloat) -> String {
        if typingRate > 8 { return "ッッターン！！" }     // 促音の重畳=圧倒的
        if typingRate > 4.5 { return "ッターン！" }
        if typingRate < 1.5 { return "たん" }             // ひらがな=弱い・かわいい
        return "ターン！"
    }

    /// 打鍵中: タイピング速度で揺らぐ
    public static func typingWord(rate: CGFloat) -> String {
        if rate > 9 { return "ダダダダッ" }
        if rate > 5.5 { return "カタカタカタ" }
        if rate < 2.5 { return "ポチポチ" }
        return "カチャカチャ"
    }
}

// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OnomatopeCursor",
    platforms: [.macOS(.v12)],
    targets: [
        // 純ロジック（AppKit非依存）: 特徴量トラッカー・分類器・研究ログ
        .target(name: "OnomatopeCore"),
        // メニューバーアプリ本体
        .executableTarget(name: "OnomatopeCursor", dependencies: ["OnomatopeCore"]),
        // テストランナー（XCTest非依存 — Xcode無しのCommand Line Toolsだけで走る）
        //   実行: swift run onomatope-tests
        .executableTarget(name: "onomatope-tests", dependencies: ["OnomatopeCore"],
                          path: "Sources/OnomatopeTests"),
        // 合成軌跡データ生成（ML蒸留用）: swift run onomatope-synth <出力dir> [セッション数]
        .executableTarget(name: "onomatope-synth", dependencies: ["OnomatopeCore"],
                          path: "Sources/OnomatopeSynth"),
        // θ→描き文字ヘッドレスレンダラ（Track B）: swift run onomatope-render <word> <v g e r> <out.png>
        .executableTarget(name: "onomatope-render", dependencies: ["OnomatopeCore"],
                          path: "Sources/OnomatopeRender"),
        // ティザー動画用の透過フレーム連番レンダラ: swift run onomatope-teaser <outdir>
        .executableTarget(name: "onomatope-teaser", dependencies: ["OnomatopeCore"],
                          path: "Sources/OnomatopeTeaser"),
    ]
)

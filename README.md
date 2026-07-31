<p align="center">日本語 | <a href="README.en.md">English</a> | <a href="README.zh.md">中文</a> | <a href="README.ko.md">한국어</a> | <a href="README.fr.md">Français</a></p>

<div align="center">

# 👀 OnomatopeCursor

**マウスカーソルが、あなたの動きをオノマトペで実況する。**
*Your cursor narrates how you move — in manga sound words.*

![OnomatopeCursor teaser](figures/teaser.gif)

[![Download](https://img.shields.io/github/v/release/ochyai/OnomatopeCursor?label=⬇%20Download&style=for-the-badge&color=ff6b3d)](https://github.com/ochyai/OnomatopeCursor/releases/latest)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.21712979.svg)](https://doi.org/10.5281/zenodo.21712979)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![macOS 12+](https://img.shields.io/badge/macOS-12%2B%20Universal-black?logo=apple)

</div>

カーソルは半世紀のあいだ「**どこ**を指しているか」しか語りませんでした。でも私たちの手は、ためらったり、勢いづいたり、ぐるぐる迷ったり——動きにはいつも**質感**があります。OnomatopeCursorは、その質感をリアルタイムに読み取り、日本語のオノマトペとして、漫画の描き文字でカーソルの上に実況するmacOSアプリです。

ゆっくり動かせば **ソロソロ**。勢いよく振れば **ビューン**。急に止めれば、赤い **ピタッ!!** が画面に叩きつけられます。そっとクリックは **ポチ**、強く押せば **バチンッ**。ファイルを放り投げれば **ポーイッ！**。そして5秒じっとしていると、カーソルは **すぅすぅ** と寝息を立てはじめます。

語彙は選ぶものではなく、**あなたの身体の鏡**です。使っているうちに、「ピタッ!!と言われたから止まった気がする」という不思議な因果の逆転が起きはじめます——それがこのプロジェクトの研究テーマでもあります（[論文](#-論文--paper)へ）。

<div align="center">

![Key visual](figures/key_visual.png)

</div>

## ⚡ 1分ではじめる

1. **[最新リリースをダウンロード](https://github.com/ochyai/OnomatopeCursor/releases/latest)**（Apple公証済み・無料）
2. zipを開いて `OnomatopeCursor.app` をアプリケーションフォルダへ
3. 起動 → メニューバーに 👀 が出たら、マウスを動かすだけ

追加の設定・権限は一切不要です（キーボード等の拡張チャネルを使う場合のみ後述の許可が要ります）。

## 🖱 動きが、ことばになる — 15の運動語

60Hzでカーソルの速度・ジャーク・方向転換・回転・直進度を読み、動きの質を15語に分類します。

<div align="center">

![Eight motion words](figures/teaser_words.png)

</div>

| あなたの動き | ことば |
|---|---|
| ゆっくり慎重に | **ソロソロ**（極低速なら **ジリジリ**） |
| なめらかにスーッと | **スーッ**・曲線なら **スイスイ** |
| 速くまっすぐ | **ビューン**（荒れていると **ダダダッ**） |
| 左右にきょろきょろ | **キョロキョロ**・激しければ **ブンブン** |
| 上下にぴょんぴょん | **ピョンピョン** |
| ぐるぐる回す | **グルグル**・小さく回せば **クルクル** |
| あてもなく徘徊 | **ウロウロ** |
| 動きが乱れて慌てる | **オロオロ** |
| その場で震える | **プルプル** |
| 高速から急停止 | **ピタッ!!**（衝撃エフェクトつき） |

## 🎚 動作の「質」が語形を変える — 音象徴の形態論

このアプリの核は「イベント→固定の語」ではなく「**動作の質→語のかたち**」です。日本語の音象徴——**濁音=重さ、促音=鋭さ、長音=持続、反復=繰り返し**——を連続パラメータ化し、同じクリックでも強さで語形が変わります。

<div align="center">

![Interaction design space](figures/design_space.png)

</div>

- クリックの強さで：**ポチ → ポチッ → カチッ → バチンッ**
- ドロップの勢いで：そっと置けば **ポトッ**、放り投げれば **ポーイッ！**、長く運んでドサッと置けば **ドサッ**
- Enterの勢いで：**たん → ターン！ → ッターン！ → ッッターン！！**
- タイピングの速さで：**ポチポチ → カチャカチャ → カタカタカタ → ダダダダッ**

## 🤖 生成モード — その場で新しいオノマトペが生まれる

メニューの「生成モード」をONにすると、辞書から選ぶのをやめて、**オンデバイスの小さなトランスフォーマー（OnomaFormer、0.4Mパラメータ・約10ms/語）が動きの質から新しい語をその場で合成**します。2,782語の日本語オノマトペで学習し、形態4次元＋意味6次元（衝撃・運動・質感・情動・光・乾湿）を条件に、同じ動きでも毎回すこし違う「生まれたての語」が出てきます。

<div align="center">

![Morphology space](figures/morphology_space.png)

</div>

ただし**音源がはっきりしているイベントは語の族を守ります**：打鍵は必ずカタカタ系、Enterはターン／かーん系。生成の自由は族の中だけ——これが「言い当てられている」感覚を壊さないための設計です。

## ✍️ 漫画の描き文字レンダリング

文字はフォントをそのまま出しません。グリフを輪郭化し、**手描き風のゆらぎ（8fpsのボイル）**、**筆圧・入り抜き・かすれ**をかけ、語ごとに固有のアニメーション（ピタッ!!の衝撃着地、グルグルの回転、ドキドキの鼓動…）で動かします。強い語は大きく赤く深い影で、静かな語は小さく淡く——重さがそのまま見た目になります。

- 動きの強度で文字サイズが0.8〜1.9倍にスケール
- ビューン/ダダダッにはスピード線、衝撃語にはバースト
- 描き文字のスタイルは**審美探索ループ**（レンダリング→視覚言語モデルの審査→回帰）で継続的に改善されます
- ごちゃごちゃする時は **表示 → 高視認スタイル（白文字＋影）** でシンプルに。エフェクト自体のON/OFFも可能

## ⌨️ カーソルの外側も — 7つの入力チャネル

| チャネル | ことば | 必要な許可 |
|---|---|---|
| カーソル運動 | 上の15語＋生成語 | なし |
| クリック・長押し・右クリック（物理モード） | ポチッ／グッ／ミギクリッ！ | なし |
| ドラッグ＆ドロップ（物理モード） | グイグイ・ズルズル → ポィ！ | なし |
| ウィンドウの縁をまたぐ（物理モード） | **カタッ**（連続で**ガタガタッ**）——平らな画面に「段差」の触感が生まれます | なし |
| スクロール（トラックパッドモード） | スルスル・ガーッ・シュルシュル | アクセシビリティ |
| 打鍵・Enter（キーボードモード） | カタカタ・**ッターン！**——文字はキャレット位置に出ます | アクセシビリティ※ |
| 静止 | すぅすぅ・ウトウト・ぼー…・たまに**ビクビクッ** | なし |

※キーボードモードは「キーを押した事実」だけを使います。**どのキーか・入力内容は一切読みません。** 背景モード（カーソル下の要素で フムフム／ジロジロ／ドキドキ が出る実験機能）も同様にアクセシビリティ許可制です。

## 🌏 5言語対応

日本語・English・中文・한국어・Français。翻訳ではなく、**各言語の音象徴の道具立てで再設計**しています（英語は大文字化と母音伸長、韓国語は子音の緊張化と母音交替…）。メニューからいつでも切替可能。

## 🎮 あそぶ

- **オノマトペ図鑑**：出会った語がコレクションされていきます。まだ見ぬ語もシルエットで
- **召喚チャレンジ**：お題の語を「動きで」出せるか——語彙が身体を引っぱり出す体験
- **2択クイズ**：たまに「どっちが自然？」と聞かれます。答えると語彙の進化に反映
- **貢献ポイント**：フィードバックで貯まり、新しい語がアンロックされて配信されます

## 🔬 研究モード（すべて任意・オプトイン）

これは筑波大学デジタルネイチャー研究室のHCI研究プロジェクトでもあります。

- **データ提供に協力**：匿名IDつきで運動特徴量・表示語・フィードバックのみを研究サーバーへ（内容は有効化のたびに明示・いつでもOFF）
- **研究ログ**：このMacの中だけに保存。提出前に中身を自分で確認できます
- **変な語が出たら右クリック2連打**＝「チガウチガウ」。研究への大事なフィードバックです

既定では**通信も記録も一切ありません**。画面の内容・キー入力の中身・クリック先はどのモードでも読みません → [PRIVACY.md](PRIVACY.md)

## 📄 論文 / Paper

> **Onomatopoeia Cursor: Verbal Mirroring of Mouse Movement with Comic-Style Lettering**
> Yoichi Ochiai, Miki Okamura — *Digital Nature Group, University of Tsukuba*
>
> [**PDF**](paper/onomatope-cursor-arxiv.pdf) · [**DOI: 10.5281/zenodo.21712979**](https://doi.org/10.5281/zenodo.21712979) · arXiv（審査中）

動きの言語的ミラーリングのデザインスペース、音象徴形態論の連続パラメータ化、オンデバイス生成、そして中心仮説——**自分の動きに言葉が与えられると、行為の主体感（sense of agency）が変容する**。「ピタッ!!が出たからカーソルが止まった気がする」という因果の逆転（ポストディクション）を、配布可能なアプリの形で実験可能にする試みです。

```bibtex
@misc{ochiai2026onomatopoeiacursor,
  author = {Ochiai, Yoichi and Okamura, Miki},
  title  = {Onomatopoeia Cursor: Verbal Mirroring of Mouse Movement
            with Comic-Style Lettering},
  year   = {2026},
  doi    = {10.5281/zenodo.21712979},
  url    = {https://doi.org/10.5281/zenodo.21712979}
}
```

## 🛠 ソースからビルド

```bash
git clone https://github.com/ochyai/OnomatopeCursor.git
cd OnomatopeCursor
swift run onomatope-tests   # テスト（76本・XCTest非依存）
./scripts/build.sh          # → dist/OnomatopeCursor-<ver>.zip
```

macOS 12+ / Apple Silicon & Intel Universal。依存ライブラリなし（AppKit + Accelerate のみ）。OnomaFormerの推論も純Swift/BLASで、coremltools等は使いません。

## License

[MIT](LICENSE) © Yoichi Ochiai & Miki Okamura, Digital Nature Group, University of Tsukuba

<div align="center">

# 👀 OnomatopeCursor

**マウスカーソルが、あなたの動きをオノマトペで実況する。**
*Your cursor narrates how you move — in manga sound words.*

![OnomatopeCursor teaser](figures/teaser.gif)

[![Download](https://img.shields.io/github/v/release/ochyai/OnomatopeCursor?label=⬇%20Download&style=for-the-badge&color=ff6b3d)](https://github.com/ochyai/OnomatopeCursor/releases/latest)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.21712979.svg)](https://doi.org/10.5281/zenodo.21712979)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![macOS 12+](https://img.shields.io/badge/macOS-12%2B%20Universal-black?logo=apple)

ゆっくり動かせば **ソロソロ**、勢いよく振れば **ビューン**、急に止めれば **ピタッ!!**
そっとクリックは **ポチ**、強く押せば **バチンッ**。ファイルを放り投げれば **ポーイッ！**

</div>

---

## ⚡ 1分ではじめる

1. **[最新リリースをダウンロード](https://github.com/ochyai/OnomatopeCursor/releases/latest)**（Apple公証済み・無料）
2. zipを開いて `OnomatopeCursor.app` をアプリケーションフォルダへ
3. 起動 → メニューバーに 👀 が出たら、マウスを動かすだけ

<div align="center">

![Eight motion words](figures/teaser_words.png)

</div>

## ✨ なにが起きるか

| 動き | ことば |
|---|---|
| ゆっくり慎重に | ソロソロ・ジリジリ |
| 左右にきょろきょろ | キョロキョロ・ブンブン |
| 速くまっすぐ | ビューン・スーッ |
| ぐるぐる回す | グルグル・クルクル |
| 急停止 | **ピタッ!!** |
| クリックの強さで | ポチ → ポチッ → カチッ → **バチンッ** |
| ドラッグ＆ドロップ | グイグイ → ポトッ／ポーイッ！ |
| じっとしていると | すぅすぅ…（カーソルが寝ます） |

- **生成モード**: オンデバイスの小さなトランスフォーマー（OnomaFormer, 0.4Mパラメータ）が、動きの質からその場で**新しいオノマトペを生成**。同じ動きでも毎回すこし違う語が生まれます
- **音象徴の形態論**: 濁音=重さ、促音=鋭さ、長音=持続、反復=繰り返し——日本語の音の直観を連続パラメータにして語形を合成
- **描き文字レンダリング**: 手描き風のゆらぎ（ボイル）・筆圧・かすれ・語ごとのアニメーション。漫画の描き文字の文法に基づきます
- **5言語対応**: 日本語・English・中文・한국어・Français（翻訳ではなく各言語の音象徴で再設計）
- **プライバシー第一**: 既定では通信も記録も一切なし。キー入力の中身・画面内容は読みません → [PRIVACY.md](PRIVACY.md)

## 📄 論文 / Paper

> **Onomatopoeia Cursor: Verbal Mirroring of Mouse Movement with Comic-Style Lettering**
> Yoichi Ochiai, Miki Okamura — *Digital Nature Group, University of Tsukuba*
>
> [**PDF**](paper/onomatope-cursor-arxiv.pdf) · [**DOI: 10.5281/zenodo.21712979**](https://doi.org/10.5281/zenodo.21712979) · arXiv（審査中）

カーソルは半世紀のあいだ「どこを指すか」しか語りませんでした。本研究は「**どう動いたか**」をリアルタイムに言語化する初のシステム実装と、そのデザインスペース、そして中心仮説——**自分の動きに言葉が与えられると、行為の主体感（sense of agency）が変容する**——を提示します。「ピタッ!!が出たからカーソルが止まった気がする」という因果の逆転（ポストディクション）を、実験可能な形で世に出す試みです。

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

## 🔬 研究に協力する（任意）

これはHCI研究プロジェクトです。使うだけでも歓迎ですが、メニュー → **研究モード → データ提供に協力** をONにすると、匿名の運動-語データが研究に届きます（内容は有効化時に明示・いつでもOFF・[PRIVACY.md](PRIVACY.md)）。

- 変な語が出たら**右クリック2連打**=「チガウチガウ」で教えてください（重要なデータになります）
- [語ズレ報告・リクエストはIssueへ](https://github.com/ochyai/OnomatopeCursor/issues)

## 🛠 ソースからビルド

```bash
git clone https://github.com/ochyai/OnomatopeCursor.git
cd OnomatopeCursor
swift run onomatope-tests   # テスト（76本）
./scripts/build.sh          # → dist/OnomatopeCursor-<ver>.zip
```

macOS 12+ / Apple Silicon & Intel Universal。依存ライブラリなし（AppKit + Accelerate のみ）。

## License

[MIT](LICENSE) © Yoichi Ochiai & Miki Okamura, Digital Nature Group, University of Tsukuba

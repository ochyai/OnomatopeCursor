<p align="center"><a href="README.md">日本語</a> | English | <a href="README.zh.md">中文</a> | <a href="README.ko.md">한국어</a> | <a href="README.fr.md">Français</a></p>

<div align="center">

# 👀 OnomatopeCursor

**Your mouse cursor gives a live play-by-play of how you move.**
*Your cursor narrates how you move — in manga sound words.*

![OnomatopeCursor teaser](figures/teaser.gif)

[![Download](https://img.shields.io/github/v/release/ochyai/OnomatopeCursor?label=⬇%20Download&style=for-the-badge&color=ff6b3d)](https://github.com/ochyai/OnomatopeCursor/releases/latest)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.21712979.svg)](https://doi.org/10.5281/zenodo.21712979)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![macOS 12+](https://img.shields.io/badge/macOS-12%2B%20Universal-black?logo=apple)

</div>

For half a century, the cursor has only ever told you **where** it is pointing. But our hands hesitate, gather momentum, circle around in indecision — movement always has **texture**. OnomatopeCursor is a macOS app that reads that texture in real time and calls it out above your cursor as onomatopoeia, hand-lettered like a comic panel.

Inch along carefully and you get **creeep…**（ソロソロ）. Whip the mouse across the screen and it's **ZOOOM!**（ビューン）. Slam to a stop and a red **SKRRT!!**（ピタッ!!）hits the screen like a punch. A gentle click is **tik**（ポチ）; a hard one is **SMACK!!**（バチンッ）. Fling a file across the desktop and it's **YEET!**（ポーイッ！）. Sit still for five seconds and your cursor starts breathing in its sleep: **zzz…**（すぅすぅ）.

The vocabulary isn't something you choose — it's **a mirror of your own body**. Use it for a while and a strange reversal of causality creeps in: *"the SKRRT!! appeared, so I guess I stopped."* That reversal is exactly what this project studies (see [the paper](#-paper)).

<div align="center">

![Key visual](figures/key_visual.png)

</div>

## ⚡ Up and running in a minute

1. **[Download the latest release](https://github.com/ochyai/OnomatopeCursor/releases/latest)** (notarized by Apple, free)
2. Unzip and drag `OnomatopeCursor.app` into your Applications folder
3. Launch it — once 👀 shows up in the menu bar, just move your mouse

No setup, no permissions required. (Only the optional extended channels, described below, ask for anything.)

## 🖱 Movement becomes language — 15 motion words

At 60 Hz it reads your cursor's speed, jerk, direction changes, rotation, and straightness, then sorts the quality of the motion into 15 words.

<div align="center">

![Eight motion words](figures/teaser_words.png)

</div>

| How you move | What it says |
|---|---|
| Slow and careful | **creeep…**（ソロソロ）— at a crawl, **inch inch…**（ジリジリ） |
| Smooth and flowing | **gliiide**（スーッ）— on a curve, **swish swish**（スイスイ） |
| Fast and straight | **ZOOOM!**（ビューン）— ragged, **DADADASH!**（ダダダッ） |
| Darting side to side | **peek peek**（キョロキョロ）— wildly, **WHOOM WHOOM**（ブンブン） |
| Bouncing up and down | **boing boing**（ピョンピョン） |
| Big loops | **whirrrr**（グルグル）— tight little ones, **twirl~**（クルクル） |
| Wandering with no destination | **pace pace…**（ウロウロ） |
| Flustered, motion falling apart | **flail flail**（オロオロ） |
| Trembling in place | **shake shake**（プルプル） |
| Full speed to a dead stop | **SKRRT!!**（ピタッ!!）— with an impact effect |

## 🎚 The *quality* of an action reshapes the word — sound-symbolic morphology

The core of this app isn't "event → fixed word," it's "**quality of action → shape of word**." The sound symbolism of Japanese — **voicing = weight, gemination = sharpness, elongation = duration, reduplication = repetition** — is turned into continuous parameters, so the same click comes out differently depending on how hard you hit it. Each language gets the same treatment with its own devices: in English, capitalization and voiced stops carry weight, doubled final consonants and `KA-` carry impact, stretched vowels carry duration.

<div align="center">

![Interaction design space](figures/design_space.png)

</div>

- Click harder: **tik**（ポチ）→ **tick!**（ポチッ）→ **CLICK!**（カチッ）→ **SMACK!!**（バチンッ）
- Drop with more force: set it down gently for **plip**（ポトッ）, hurl it for **YEET!**（ポーイッ！）, haul it a long way and let it land for **THUD!**（ドサッ）
- Hit Enter with more conviction: **tap**（たん）→ **CLACK!**（ターン！）→ **KA-CLACK!**（ッターン！）→ **KA-BLAMM!!**（ッッターン！！）
- Type faster: **tik tik**（ポチポチ）→ **clack clack**（カチャカチャ）→ **clakclakclak**（カタカタカタ）→ **DAKKADAKKA!**（ダダダダッ）

## 🤖 Generative mode — brand-new onomatopoeia, invented on the spot

Flip on "Generative Mode" in the menu and the app stops picking from a dictionary. Instead, **a tiny on-device transformer (OnomaFormer, 0.4M parameters, ~10 ms per word) synthesizes a new word from the quality of your motion**. It's trained on 2,782 Japanese onomatopoeia and conditioned on 4 morphological dimensions plus 6 semantic ones (impact, motion, texture, emotion, light, wetness), so even the same gesture yields a slightly different, freshly minted word each time.

<div align="center">

![Morphology space](figures/morphology_space.png)

</div>

That said, **events with an unmistakable physical sound source keep their word family**: keystrokes always land in the clack family, Enter always in the CLACK / KA-CLACK family. Generative freedom exists only *within* the family — that constraint is what keeps the "it named exactly what I did" feeling from breaking.

## ✍️ Comic-style hand-lettering

The text isn't just a font on screen. Glyphs are converted to outlines, then given **hand-drawn wobble (an 8 fps boil)**, **pressure, entry/exit strokes, and dry-brush breakup**, and animated with per-word motion (the crash landing of a SKRRT!!, the spin of a whirrrr, the pulse of a thump thump…). Strong words come out big, red, and deep-shadowed; quiet words small and pale — weight becomes appearance directly.

- Letter size scales 0.8×–1.9× with motion intensity
- Speed lines for ZOOOM! / DADADASH!, bursts for impact words
- The lettering style keeps improving through an **aesthetic search loop** (render → vision-language model judges → regression)
- If it gets too busy, switch to **View → High-Visibility Style (white text + shadow)**. You can also turn the effects off entirely

## ⌨️ Beyond the cursor — 7 input channels

| Channel | Words | Permission needed |
|---|---|---|
| Cursor motion | the 15 words above + generated ones | None |
| Click, press-and-hold, right-click (physics mode) | **tick!**（ポチッ）/ **hooold…**（グッ）/ **R-CLICK!**（ミギクリッ！） | None |
| Drag & drop (physics mode) | **tug tug**（グイグイ）, **drrraag…**（ズルズル）→ **plop!**（ポィ！） | None |
| Crossing a window edge (physics mode) | **clunk**（カタッ）, or **KLUNKKLUNK!**（ガタガタッ）in a row — a flat screen suddenly has texture underfoot | None |
| Scrolling (trackpad mode) | **scroooll**（スルスル）, **VRRRRT!**（ガーッ）, **zwip zwip**（シュルシュル） | Accessibility |
| Typing & Enter (keyboard mode) | **clack clack**（カチャカチャ）, **KA-CLACK!**（ッターン！）— lettering appears at the caret | Accessibility* |
| Stillness | **zzz…**（すぅすぅ）, **dozing…**（ウトウト）, **blaaank…**（ぼー…）, occasionally **JOLT!!**（ビクビクッ） | None |

\* Keyboard mode uses only the *fact* that a key was pressed. **It never reads which key, or what you typed.** Context mode (an experimental feature where **hmm hmm**（フムフム）/ **staaare**（ジロジロ）/ **thump thump**（ドキドキ）respond to the element under your cursor) is likewise gated behind Accessibility permission.

## 🌏 Five languages

日本語, English, 中文, 한국어, Français. These aren't translations — each language is **redesigned around its own sound-symbolic toolkit** (English uses capitalization and vowel stretching, Korean uses consonant tensing and vowel alternation, and so on). Switch any time from the menu.

## 🎮 Play

- **Onomatopoeia Encyclopedia**: every word you meet gets collected. The ones you haven't found yet show up as silhouettes
- **Summoning Challenge**: can you produce a given word *with your movement alone*? Vocabulary pulling the body out of you
- **A/B Quiz**: now and then it asks "which one feels more natural?" Your answer feeds back into the vocabulary's evolution
- **Contribution Points**: earned through feedback, and they unlock new words that get shipped out to everyone

## 🔬 Research mode (entirely optional, opt-in)

This is also an HCI research project from the Digital Nature Group at the University of Tsukuba.

- **Contribute data**: only motion features, displayed words, and feedback go to the research server, under an anonymous ID (exactly what's sent is spelled out each time you enable it, and you can turn it off whenever)
- **Research log**: stored only on this Mac. You can read the whole thing yourself before submitting
- **See a word that feels wrong? Double right-click** = "nope nope"（チガウチガウ）. That's valuable research feedback

By default there is **no networking and no logging whatsoever**. In no mode does the app read your screen contents, your keystrokes, or what you click on → [PRIVACY.md](PRIVACY.md)

## 📄 Paper

> **Onomatopoeia Cursor: Verbal Mirroring of Mouse Movement with Comic-Style Lettering**
> Yoichi Ochiai, Miki Okamura — *Digital Nature Group, University of Tsukuba*
>
> [**PDF**](paper/onomatope-cursor-arxiv.pdf) · [**DOI: 10.5281/zenodo.21712979**](https://doi.org/10.5281/zenodo.21712979) · arXiv (under review)

The paper covers the design space of linguistic mirroring of movement, the continuous parameterization of sound-symbolic morphology, on-device generation, and the central hypothesis: **when your own movement is given words, your sense of agency over the act is transformed.** The reversal of causality — postdiction — behind *"the SKRRT!! came out, so I feel like that's what stopped the cursor"* is here made experimentally testable in the form of an app anyone can install.

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

## 🛠 Build from source

```bash
git clone https://github.com/ochyai/OnomatopeCursor.git
cd OnomatopeCursor
swift run onomatope-tests   # tests (76 of them, no XCTest dependency)
./scripts/build.sh          # → dist/OnomatopeCursor-<ver>.zip
```

macOS 12+ / Universal for Apple Silicon & Intel. Zero dependencies (AppKit + Accelerate only). OnomaFormer inference is pure Swift/BLAS — no coremltools, nothing else.

## License

[MIT](LICENSE) © Yoichi Ochiai & Miki Okamura, Digital Nature Group, University of Tsukuba

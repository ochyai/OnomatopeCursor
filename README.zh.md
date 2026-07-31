<p align="center"><a href="README.md">日本語</a> | <a href="README.en.md">English</a> | 中文 | <a href="README.ko.md">한국어</a> | <a href="README.fr.md">Français</a></p>

<div align="center">

# 👀 OnomatopeCursor

**鼠标光标，为你的每一次移动配上拟声词解说。**
*Your cursor narrates how you move — in manga sound words.*

![OnomatopeCursor teaser](figures/teaser.gif)

[![Download](https://img.shields.io/github/v/release/ochyai/OnomatopeCursor?label=⬇%20Download&style=for-the-badge&color=ff6b3d)](https://github.com/ochyai/OnomatopeCursor/releases/latest)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.21712979.svg)](https://doi.org/10.5281/zenodo.21712979)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![macOS 12+](https://img.shields.io/badge/macOS-12%2B%20Universal-black?logo=apple)

</div>

半个世纪以来，光标只会告诉你它指着**哪里**。可我们的手会犹豫、会加速、会绕着圈子迷路——动作永远带着**质感**。OnomatopeCursor 是一款 macOS 应用，它实时读取这份质感，用漫画描字的笔触，把它作为拟声词现场解说在光标之上。

慢慢挪动，是 **蹑手蹑脚**（ソロソロ）。猛地一甩，是 **嗖——!**（ビューン）。突然刹住，一个红色的 **刹!!**（ピタッ!!）就砸在屏幕上。轻轻点一下是 **哒**（ポチ），用力按下去是 **啪嚓!!**（バチンッ）。把文件甩出去，则是 **咻——!**（ポーイッ！）。而如果你静止五秒，光标就会开始 **呼…呼…**（すぅすぅ）地打起呼噜。

词汇不是你挑出来的，而是**你身体的镜子**。用着用着，会开始发生一种奇妙的因果倒置——「因为它说了『刹!!』，我才觉得自己停住了」。这也正是本项目的研究主题（前往[论文](#-论文--paper)）。

<div align="center">

![Key visual](figures/key_visual.png)

</div>

## ⚡ 一分钟上手

1. **[下载最新版本](https://github.com/ochyai/OnomatopeCursor/releases/latest)**（已通过 Apple 公证・免费）
2. 解压 zip，把 `OnomatopeCursor.app` 拖进「应用程序」文件夹
3. 启动 → 菜单栏出现 👀 之后，动动鼠标就行

无需任何额外设置或权限（只有使用键盘等扩展通道时，才需要后文提到的授权）。

## 🖱 动作，变成语言 — 15 个运动词

以 60Hz 读取光标的速度、加加速度（jerk）、转向、旋转与直线度，把动作的质感分类为 15 个词。

<div align="center">

![Eight motion words](figures/teaser_words.png)

</div>

| 你的动作 | 词 |
|---|---|
| 缓慢而谨慎 | **蹑手蹑脚**（ソロソロ）（极慢时为 **蹭…蹭…** / ジリジリ） |
| 顺滑地滑过去 | **哧溜~**（スーッ）・走弧线则是 **哧溜哧溜**（スイスイ） |
| 又快又直 | **嗖——!**（ビューン）（抖动较大时为 **噔噔噔!** / ダダダッ） |
| 左右东张西望 | **东瞅西瞅**（キョロキョロ）・幅度激烈则是 **呼呼**（ブンブン） |
| 上下蹦跳 | **蹦蹦**（ピョンピョン） |
| 大圈打转 | **骨碌骨碌**（グルグル）・小圈快转则是 **滴溜溜**（クルクル） |
| 漫无目的地游荡 | **晃悠晃悠**（ウロウロ） |
| 动作紊乱、手忙脚乱 | **团团转**（オロオロ） |
| 原地发抖 | **抖抖抖**（プルプル） |
| 高速中骤然急停 | **刹!!**（ピタッ!!）（附带冲击特效） |

## 🎚 动作的「质」改变词的形态 — 音象征形态论

这款应用的内核不是「事件→固定的词」，而是「**动作的质→词的形状**」。它把音象征——在日语里是**浊音=重量、促音=锐利、长音=持续、叠用=重复**，在中文里则由**用字的升级、长音线「——」、感叹号的个数、叠字与四字连绵语**来承担——参数化为连续量，于是同样是点击，力度不同，词形就不同。

<div align="center">

![Interaction design space](figures/design_space.png)

</div>

- 随点击力度变化：**哒 → 哒! → 咔! → 啪嚓!!**（ポチ → ポチッ → カチッ → バチンッ）
- 随放下的势头变化：轻轻放下是 **吧嗒**（ポトッ），甩出去是 **咻——!**（ポーイッ！），拖了很久再重重落下则是 **咚!!**（ドサッ）
- 随回车的力道变化：**嗒 → 啪! → 啪——!! → 哐——!!!**（たん → ターン！ → ッターン！ → ッッターン！！）
- 随打字速度变化：**嗒嗒 → 咔嗒咔嗒 → 噼里啪啦 → 哒哒哒哒!!**（ポチポチ → カチャカチャ → カタカタカタ → ダダダダッ）

## 🤖 生成模式 — 崭新的拟声词就地诞生

在菜单里打开「生成模式」，应用就不再从词典里挑词，而是由**设备端的小型 Transformer（OnomaFormer，0.4M 参数・约 10ms/词）根据动作的质感当场合成新词**。它以 2,782 个日语拟声词训练而成，以形态 4 维＋语义 6 维（冲击・运动・质感・情绪・光・干湿）为条件，即使是同一个动作，每次也会冒出略有不同的、刚刚出生的词。

<div align="center">

![Morphology space](figures/morphology_space.png)

</div>

不过，**声源明确的事件会守住词族**：敲键盘必定属于咔嗒系，回车必定属于 啪／哐 系。生成的自由只存在于词族内部——这是为了不破坏那种「被说中了」的感觉而做的设计。

## ✍️ 漫画描字渲染

文字并不是把字体原样输出。应用会把字形轮廓化，施加**手绘感的抖动（8fps 的 boil）**、**笔压・起收笔・飞白**，再按每个词专属的动画让它动起来（刹!! 的冲击落地、骨碌骨碌 的旋转、怦怦 的心跳……）。强的词又大又红、影子很深，安静的词又小又淡——重量直接变成外观。

- 文字大小随动作强度在 0.8〜1.9 倍之间缩放
- 嗖——! / 噔噔噔! 配速度线，冲击类词配爆裂效果
- 描字风格会通过**审美探索循环**（渲染→视觉语言模型评审→回归）持续改进
- 觉得画面太乱时，可切到 **显示 → 高辨识度样式（白字＋阴影）**。特效本身也可以整体开关

## ⌨️ 光标之外 — 7 条输入通道

| 通道 | 词 | 所需权限 |
|---|---|---|
| 光标运动 | 上述 15 个词＋生成词 | 无 |
| 点击・长按・右键（物理模式） | 哒!／摁——／右咔!（ポチッ／グッ／ミギクリッ！） | 无 |
| 拖放（物理模式） | 嘿咻嘿咻・哧啦哧啦 → 咻!（グイグイ・ズルズル → ポィ！） | 无 |
| 跨过窗口边缘（物理模式） | **咔嗒**（カタッ）（连续时为**哐当哐当!** / ガタガタッ）——平坦的屏幕上长出了「台阶」的触感 | 无 |
| 滚动（触控板模式） | 刷刷~・哗——!!・咻噜咻噜（スルスル・ガーッ・シュルシュル） | 辅助功能 |
| 敲键・回车（键盘模式） | 咔嗒咔嗒・**啪——!!**（ッターン！）——文字出现在光标插入点位置 | 辅助功能※ |
| 静止 | 呼…呼…・打盹…・发呆…・偶尔**激灵!**（すぅすぅ・ウトウト・ぼー…・ビクビクッ） | 无 |

※键盘模式只使用「按下了某个键」这一事实。**按的是哪个键、输入了什么内容，一概不读取。** 背景模式（根据光标下方的元素显示 嗯嗯~／盯——／怦怦 的实验性功能）同样需要辅助功能授权。

## 🌏 支持 5 种语言

日本語・English・中文・한국어・Français。这不是翻译，而是**用各语言自己的音象征工具重新设计**（英语用大写化与元音拉长，韩语用辅音紧音化与元音交替，中文用用字的轻重升级、长音线与叠字……）。随时可从菜单切换。

## 🎮 玩起来

- **拟声词图鉴**：遇到过的词会被收集起来。还没见过的词以剪影显示
- **召唤挑战**：能不能「用动作」把指定的词召唤出来——一种由词汇把身体牵引出来的体验
- **二选一小测**：偶尔会问你「哪个更自然？」。你的回答会反馈到词汇的进化中
- **贡献点数**：通过反馈累积，可解锁并推送新的词

## 🔬 研究模式（全部自愿・选择加入）

这同时也是筑波大学 Digital Nature 研究室的一个 HCI 研究项目。

- **协助提供数据**：仅将运动特征量、显示的词与反馈附上匿名 ID 送往研究服务器（每次启用时都会明示内容・随时可关闭）
- **研究日志**：只保存在这台 Mac 里。提交前你可以自己检查内容
- **出现奇怪的词时连按两次右键**＝「不对不对」（チガウチガウ）。这是对研究非常重要的反馈

默认状态下**既不通信，也不记录任何东西**。屏幕内容、按键内容、点击对象，在任何模式下都不会被读取 → [PRIVACY.md](PRIVACY.md)

## 📄 论文 / Paper

> **Onomatopoeia Cursor: Verbal Mirroring of Mouse Movement with Comic-Style Lettering**
> Yoichi Ochiai, Miki Okamura（落合陽一・岡村美紀）— *Digital Nature Group, University of Tsukuba*
>
> [**PDF**](paper/onomatope-cursor-arxiv.pdf) · [**DOI: 10.5281/zenodo.21712979**](https://doi.org/10.5281/zenodo.21712979) · arXiv（审稿中）

论文讨论动作的语言化镜像的设计空间、音象征形态论的连续参数化、设备端生成，以及核心假说——**当自己的动作被赋予语言时，行为的主体感（sense of agency）会随之变化**。「因为出现了『刹!!』，我才觉得光标停住了」这种因果倒置（postdiction），本项目试图以一个可分发的应用的形式，把它变成可实验的对象。

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

## 🛠 从源码构建

```bash
git clone https://github.com/ochyai/OnomatopeCursor.git
cd OnomatopeCursor
swift run onomatope-tests   # 测试（76 项・不依赖 XCTest）
./scripts/build.sh          # → dist/OnomatopeCursor-<ver>.zip
```

macOS 12+ / Apple Silicon 与 Intel 通用二进制。无第三方依赖（仅 AppKit + Accelerate）。OnomaFormer 的推理也是纯 Swift/BLAS，不使用 coremltools 之类的工具。

## License

[MIT](LICENSE) © Yoichi Ochiai & Miki Okamura, Digital Nature Group, University of Tsukuba

<p align="center"><a href="README.md">日本語</a> | <a href="README.en.md">English</a> | <a href="README.zh.md">中文</a> | 한국어 | <a href="README.fr.md">Français</a></p>

<div align="center">

# 👀 OnomatopeCursor

**마우스 커서가 당신의 움직임을 의성어·의태어로 중계한다.**
*Your cursor narrates how you move — in manga sound words.*

![OnomatopeCursor teaser](figures/teaser.gif)

[![Download](https://img.shields.io/github/v/release/ochyai/OnomatopeCursor?label=⬇%20Download&style=for-the-badge&color=ff6b3d)](https://github.com/ochyai/OnomatopeCursor/releases/latest)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.21712979.svg)](https://doi.org/10.5281/zenodo.21712979)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![macOS 12+](https://img.shields.io/badge/macOS-12%2B%20Universal-black?logo=apple)

</div>

커서는 반세기 동안 "**어디**를 가리키고 있는가"밖에 말하지 않았습니다. 하지만 우리의 손은 망설이기도 하고, 기세를 타기도 하고, 빙글빙글 헤매기도 합니다 — 움직임에는 언제나 **질감**이 있습니다. OnomatopeCursor는 그 질감을 실시간으로 읽어내, 만화의 효과음 글씨로 커서 위에 중계하는 macOS 앱입니다.

천천히 움직이면 **살금살금**(ソロソロ). 힘차게 휘두르면 **슈웅—**(ビューン). 갑자기 멈추면 빨간 **딱!!**(ピタッ!!)이 화면에 내리꽂힙니다. 살짝 클릭하면 **톡**(ポチ), 세게 누르면 **철컥!!**(バチンッ). 파일을 휙 던지면 **휘익!!**(ポーイッ！). 그리고 5초 동안 가만히 있으면 커서는 **쌔근쌔근**(すぅすぅ) 잠든 숨소리를 내기 시작합니다.

어휘는 고르는 것이 아니라 **당신 신체의 거울**입니다. 쓰다 보면 "딱!!이라고 하길래 멈춘 것 같다"는 신기한 인과의 역전이 일어나기 시작합니다 — 그것이 이 프로젝트의 연구 주제이기도 합니다([논문](#-논문--paper)으로).

<div align="center">

![Key visual](figures/key_visual.png)

</div>

## ⚡ 1분 만에 시작하기

1. **[최신 릴리스 다운로드](https://github.com/ochyai/OnomatopeCursor/releases/latest)**(Apple 공증 완료·무료)
2. zip을 열어 `OnomatopeCursor.app`을 응용 프로그램 폴더로
3. 실행 → 메뉴 막대에 👀 가 뜨면, 마우스를 움직이기만 하면 됩니다

추가 설정이나 권한은 전혀 필요 없습니다(키보드 등 확장 채널을 쓸 때만 아래에 설명하는 허가가 필요합니다).

## 🖱 움직임이 말이 된다 — 15개의 운동어

60Hz로 커서의 속도·저크(jerk)·방향 전환·회전·직진도를 읽어, 움직임의 질을 15개 단어로 분류합니다.

<div align="center">

![Eight motion words](figures/teaser_words.png)

</div>

| 당신의 움직임 | 말 |
|---|---|
| 천천히 조심스럽게 | **살금살금**(ソロソロ)（아주 느리면 **슬금슬금**(ジリジリ)） |
| 매끄럽게 스윽 | **스으윽**(スーッ)・곡선이면 **술술**(スイスイ) |
| 빠르고 곧게 | **슈웅—**(ビューン)（거칠면 **다다닥!**(ダダダッ)） |
| 좌우로 두리번두리번 | **두리번두리번**(キョロキョロ)・격하면 **붕붕**(ブンブン) |
| 위아래로 깡충깡충 | **깡충깡충**(ピョンピョン) |
| 빙글빙글 돌리기 | **빙글빙글**(グルグル)・작게 돌리면 **뱅글뱅글**(クルクル) |
| 목적 없이 배회 | **어슬렁어슬렁**(ウロウロ) |
| 움직임이 흐트러져 허둥댐 | **허둥지둥**(オロオロ) |
| 제자리에서 떨림 | **바들바들**(プルプル) |
| 고속에서 급정지 | **딱!!**(ピタッ!!)（충격 이펙트 포함） |

## 🎚 동작의 '질'이 어형을 바꾼다 — 음상징 형태론

이 앱의 핵심은 "이벤트 → 고정된 단어"가 아니라 "**동작의 질 → 단어의 형태**"입니다. 일본어의 음상징 — **탁음=무게, 촉음=날카로움, 장음=지속, 반복=되풀이** — 을 연속 파라미터로 만들었고, 한국어판에서는 같은 축을 **모음 교체·경음화·장음화·첩어**로 구현합니다. 그래서 같은 클릭이라도 세기에 따라 어형이 달라집니다.

<div align="center">

![Interaction design space](figures/design_space.png)

</div>

- 클릭의 세기에 따라: **톡 → 톡! → 딸깍! → 철컥!!**（ポチ → ポチッ → カチッ → バチンッ）
- 드롭의 기세에 따라: 살며시 놓으면 **똑**(ポトッ), 휙 던지면 **휘익!!**(ポーイッ！), 오래 옮기다 털썩 놓으면 **털썩!**(ドサッ)
- Enter의 기세에 따라: **탁 → 타앙! → 따앙!! → 따아앙!!!**（たん → ターン！ → ッターン！ → ッッターン！！）
- 타이핑 속도에 따라: **톡톡 → 타닥타닥 → 타다다닥 → 따다다다닥!!**（ポチポチ → カチャカチャ → カタカタカタ → ダダダダッ）

## 🤖 생성 모드 — 그 자리에서 새로운 의성어가 태어난다

메뉴의 '생성 모드'를 켜면 사전에서 고르기를 멈추고, **온디바이스의 작은 트랜스포머(OnomaFormer, 0.4M 파라미터·약 10ms/단어)가 움직임의 질로부터 새로운 단어를 즉석에서 합성**합니다. 2,782개의 일본어 의성어·의태어로 학습했으며, 형태 4차원 + 의미 6차원(충격·운동·질감·정동·빛·건습)을 조건으로 삼아, 같은 움직임이라도 매번 조금씩 다른 '갓 태어난 단어'가 나옵니다.

<div align="center">

![Morphology space](figures/morphology_space.png)

</div>

다만 **음원이 분명한 이벤트는 단어의 족(族)을 지킵니다**. 타건은 반드시 타닥 계열, Enter는 타앙／따앙 계열. 생성의 자유는 족 안에서만 — 이것이 '딱 맞게 짚어냈다'는 감각을 깨뜨리지 않기 위한 설계입니다.

## ✍️ 만화 효과음 글씨 렌더링

글자는 폰트를 그대로 내보내지 않습니다. 글리프를 윤곽선화하고 **손그림 같은 흔들림(8fps 보일)**, **필압·들어가고 빠지는 획·갈필**을 입힌 뒤, 단어마다 고유한 애니메이션(딱!!의 충격 착지, 빙글빙글의 회전, 두근두근의 심장박동…)으로 움직입니다. 강한 단어는 크고 붉게 깊은 그림자로, 조용한 단어는 작고 옅게 — 무게가 그대로 겉모습이 됩니다.

- 움직임의 강도에 따라 글자 크기가 0.8~1.9배로 스케일
- 슈웅—/다다닥!에는 스피드 라인, 충격어에는 버스트
- 효과음 글씨 스타일은 **심미 탐색 루프**(렌더링 → 시각언어모델의 심사 → 회귀)로 계속 개선됩니다
- 화면이 복잡해질 때는 **표시 → 고시인성 스타일(흰 글자+그림자)** 로 심플하게. 이펙트 자체를 켜고 끌 수도 있습니다

## ⌨️ 커서 바깥까지 — 7개의 입력 채널

| 채널 | 말 | 필요한 허가 |
|---|---|---|
| 커서 운동 | 위의 15개 단어 + 생성어 | 없음 |
| 클릭·길게 누르기·우클릭（물리 모드） | 톡!／꾸욱／우클릭! | 없음 |
| 드래그 앤 드롭（물리 모드） | 쭉쭉·질질 → 휙! | 없음 |
| 창의 가장자리를 넘을 때（물리 모드） | **덜컥**(カタッ)（연속이면 **덜컹덜컹!**(ガタガタッ)） — 평평한 화면에 '턱'의 촉감이 생깁니다 | 없음 |
| 스크롤（트랙패드 모드） | 스르르·촤르륵!·슈르르 | 손쉬운 사용 |
| 타건·Enter（키보드 모드） | 타닥타닥·**따앙!!** — 글자는 캐럿 위치에 나타납니다 | 손쉬운 사용※ |
| 정지 | 쌔근쌔근·꾸벅꾸벅·멍…·가끔 **흠칫!!** | 없음 |

※키보드 모드는 '키를 눌렀다는 사실'만 사용합니다. **어떤 키인지·입력 내용은 일절 읽지 않습니다.** 배경 모드(커서 아래의 요소에 따라 끄덕끄덕／뚫어져라／두근두근 이 나오는 실험 기능)도 마찬가지로 손쉬운 사용 허가가 필요합니다.

## 🌏 5개 언어 지원

日本語・English・中文・한국어・Français. 번역이 아니라 **각 언어의 음상징 도구로 다시 설계**했습니다(영어는 대문자화와 모음 늘이기, 한국어는 자음의 경음화와 모음 교체…). 메뉴에서 언제든 전환할 수 있습니다.

## 🎮 놀기

- **의성어 도감**: 만난 단어가 컬렉션으로 쌓입니다. 아직 못 만난 단어는 실루엣으로
- **소환 챌린지**: 주어진 단어를 '움직임으로' 낼 수 있을까 — 어휘가 신체를 끌어내는 체험
- **2지선다 퀴즈**: 가끔 "어느 쪽이 자연스러워?"라고 물어봅니다. 답하면 어휘의 진화에 반영됩니다
- **기여 포인트**: 피드백으로 쌓이며, 새로운 단어가 해제되어 배포됩니다

## 🔬 연구 모드（모두 선택 사항·옵트인）

이것은 쓰쿠바대학 디지털네이처 연구실의 HCI 연구 프로젝트이기도 합니다.

- **데이터 제공에 협력**: 익명 ID와 함께 운동 특징량·표시된 단어·피드백만 연구 서버로(내용은 활성화할 때마다 명시되며, 언제든 끌 수 있습니다)
- **연구 로그**: 이 Mac 안에만 저장됩니다. 제출 전에 내용을 직접 확인할 수 있습니다
- **이상한 단어가 나오면 우클릭 두 번 연속** = "아니아니". 연구에 소중한 피드백입니다

기본 설정에서는 **통신도 기록도 일절 없습니다**. 화면의 내용·키 입력의 내용·클릭 대상은 어떤 모드에서도 읽지 않습니다 → [PRIVACY.md](PRIVACY.md)

## 📄 논문 / Paper

> **Onomatopoeia Cursor: Verbal Mirroring of Mouse Movement with Comic-Style Lettering**
> Yoichi Ochiai, Miki Okamura — *Digital Nature Group, University of Tsukuba*
>
> [**PDF**](paper/onomatope-cursor-arxiv.pdf) · [**DOI: 10.5281/zenodo.21712979**](https://doi.org/10.5281/zenodo.21712979) · arXiv（심사 중）

움직임의 언어적 미러링에 대한 디자인 스페이스, 음상징 형태론의 연속 파라미터화, 온디바이스 생성, 그리고 중심 가설 — **자신의 움직임에 말이 주어지면 행위의 주체감(sense of agency)이 변용된다**. "딱!!이 떴으니까 커서가 멈춘 것 같다"는 인과의 역전(포스트딕션)을, 배포 가능한 앱의 형태로 실험할 수 있게 만들려는 시도입니다.

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

## 🛠 소스에서 빌드하기

```bash
git clone https://github.com/ochyai/OnomatopeCursor.git
cd OnomatopeCursor
swift run onomatope-tests   # 테스트（76개·XCTest 비의존）
./scripts/build.sh          # → dist/OnomatopeCursor-<ver>.zip
```

macOS 12+ / Apple Silicon & Intel Universal. 의존 라이브러리 없음(AppKit + Accelerate만 사용). OnomaFormer의 추론도 순수 Swift/BLAS이며, coremltools 등은 쓰지 않습니다.

## License

[MIT](LICENSE) © Yoichi Ochiai & Miki Okamura, Digital Nature Group, University of Tsukuba

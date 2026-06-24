---
name: パワフル漫才 (Powerful Manzai)
version: alpha
description: パワプロ「サクセス」オマージュのポップでレトロな芸人育成ゲームUI。ネイビーの太い縁取り・クリームの面・原色ポップ・日本語ドット文字・ハードな3Dドロップシャドウ・自作ピクセルアイコンが核。
colors:
  ink: "#16234f"          # 主線・文字・縁取り(ネイビー)。ほぼ全ての境界線とドロップシャドウに使う
  ink-deep: "#0a1130"     # アプリ最外周・レターボックス・暗い舞台背景
  cream: "#fff8e6"        # パネルの面(明るい)
  panel: "#fbf2dc"        # パネルの面(やや沈んだ)
  white: "#ffffff"
  yellow: "#ffce2b"
  red: "#ff5252"
  blue: "#34a6ff"
  green: "#3ccf6e"
  orange: "#ff9a3c"
  purple: "#b06bff"
  # ネタパーツの種別カラー(育成・ネタ構成・本番ノーツで共通)
  kind-tsukami: "#b06bff"
  kind-furi: "#34a6ff"
  kind-boke: "#ffce2b"
  kind-tsukkomi: "#ff7a5c"
  kind-ochi: "#3ccf6e"
  # 能力グレードのヒート配色(パワプロ準拠: 金→桃→赤→橙→黄→緑→水→灰)
  grade-s: "#f3b500"
  grade-a: "#ff5e9c"
  grade-b: "#ff2d2d"
  grade-c: "#ff8a1f"
  grade-d: "#ffd60a"
  grade-e: "#3ccf6e"
  grade-f: "#39c5e0"
  grade-g: "#8a93a8"
typography:
  logo:                   # タイトルロゴ・大見出し(ドット文字＋太いネイビー縁取り)
    fontFamily: DotGothic16
    fontWeight: 400
    letterSpacing: "0.02em"
  heading:                # 画面見出し・モーダル見出し
    fontFamily: DotGothic16
    fontWeight: 400
  number:                 # 手応え・スコア・能力値などの大きな数字(等幅)
    fontFamily: DotGothic16
    fontWeight: 400
    fontFeature: "tabular-nums"
  label:                  # ボタン・チップ・コマンド名などUIラベル
    fontFamily: DotGothic16
    fontWeight: 400
  body:                   # 会話・流れる文字・本文。可読性最優先(ドット文字を使わない)
    fontFamily: "Hiragino Maru Gothic ProN, BIZ UDGothic, Yu Gothic"
    fontWeight: 800
    lineHeight: 1.5
  caption:                # 注釈・補足
    fontFamily: "Hiragino Maru Gothic ProN, Yu Gothic"
    fontWeight: 700
    fontSize: 11px
rounded:
  pill: 999px             # 主要ボタン・チップ・バッジ
  lg: 18px                # 大パネル
  md: 14px                # 中パネル・アイコンタイル
  sm: 10px                # 小要素・スロット
spacing:
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
components:
  appFrame:               # 全画面共通の外枠
    backgroundColor: "{colors.ink-deep}"
    width: 520px
    height: 100dvh
  button:                 # ポップなピル型ボタン(3D影＋押下沈み)
    backgroundColor: "{colors.red}"
    textColor: "{colors.white}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
    padding: "14px 32px"
  panel:                  # クリーム面＋ネイビー太縁＋ハード3D影
    backgroundColor: "{colors.cream}"
    textColor: "{colors.ink}"
    rounded: "{rounded.lg}"
    padding: "{spacing.md}"
  commandIcon:            # コマンドの丸み四角タイル(フラット単色＋白ピクセルアイコン)
    rounded: "{rounded.md}"
    size: "56px"
  numberHero:             # 手応え/スコア等のヒーロー数字バッジ
    backgroundColor: "{colors.cream}"
    textColor: "{colors.red}"
    typography: "{typography.number}"
    rounded: "{rounded.md}"
---

# パワフル漫才 — DESIGN.md

> 本ファイルは UI の一次情報源。新しい画面・部品を作るとき、色・文字・余白・部品はここのトークンに従う。
> 既存実装は各 HTML の `:root` CSS 変数に同等のトークンを持つ（順次このファイルへ集約・統一する）。

## Overview
- **コンセプト**: 「パワプロ・ポップ × レトロゲーム」。明るく親しみやすい原色ポップに、日本語ドット文字（GBA/パワポケ世代）と、ハードな立体感（太いネイビー縁＋下方向のベタ影）を重ねる。
- **トーン**: 子供っぽくなりすぎない。グラデや影で適度な厚みを出すが、ベースはフラットでクッキリ。
- **対象**: モバイル縦持ち（iPhone/Safari 優先）。最大幅 520px のアプリ枠を中央寄せ、外側は `ink-deep` のレターボックス。

## Colors
- **ink（ネイビー #16234f）が主役**。境界線・文字・3D影のほぼ全てに使う「ゲームの骨格色」。
- **面はクリーム**（`cream`/`panel`）。原色ポップ（`red`/`blue`/`yellow`/`green`/`orange`/`purple`）はアクセント・カテゴリ識別に。
- **種別カラー**（ツカミ=紫 / フリ=青 / ボケ=黄 / ツッコミ=朱 / オチ=緑）は、育成・ネタ構成・本番ノーツで**必ず同じ色**を使い、横断で意味が通るようにする。
- **能力グレード**は金(S)→桃(A)→赤(B)→橙(C)→黄(D)→緑(E)→水(F)→灰(G)のヒートスケール（パワプロ準拠）。
- コントラスト: 文字・アイコンは原色面の上では `ink` または `white`。暗背景（舞台・status）では `white`。

## Typography
- **2系統を使い分ける**:
  - **ドット文字（DotGothic16）= 表示用**: ロゴ・見出し・数字・UIラベル。レトロ感の核。等幅数字（`tabular-nums`）でスコア類が安定。
  - **可読フォント（丸ゴシック）= 本文用**: 会話・**流れる文字（漫才プレイのノーツ等）**。ドット文字は動く・小さい文字で視認性が落ちるため、流れる/長い文章には使わない。
- 大きな数字は「白縁＋ネイビーの段差影」で立体化（手応え・スコア）。
- ドット文字は `-webkit-font-smoothing: none` でくっきり表示してよい。

## Layout
- 全画面 **`appFrame`**: `position:fixed; inset:0; max-width:520px; margin:0 auto; height:100dvh`（`100vh` は使わない＝アドレスバーで見切れる）。viewport は `viewport-fit=cover, maximum-scale=1, user-scalable=no`。`env(safe-area-inset-*)` を考慮。
- 縦積みが基本。スクロールは極力避け、1画面に収める設計（収まらない時のみ内部スクロール）。
- PWA: `display:standalone` のマニフェストで「ホーム画面に追加」→全画面起動。

## Elevation & Depth
- **署名となる立体表現**: `box-shadow: 0 <N>px 0 var(--ink)`（下方向に**ベタなネイビーの段差**）＋必要に応じて柔らかい影 `0 <N>px <M>px rgba(0,0,0,.3)`。ガラスのような光沢（白いハイライト）は**多用しない**（コマンドアイコンは光沢なしのフラット）。
- 押下: `:active{ transform: translateY(<段差>px); box-shadow: 0 1px 0 var(--ink); }` で「物理的に沈む」感触。
- 縁取り: 2〜4px の `ink` ソリッド。要素が大きいほど太く。

## Shapes
- ボタン・チップ・バッジは **ピル（`rounded.pill`）**。
- パネル・モーダル・アイコンタイルは **角丸四角**（`lg`/`md`）。**真円は避ける**（コマンドアイコンは角丸四角に統一）。
- スロット等の小要素は `sm`。

## Components
- **button**: ポップなピル。原色グラデ面＋`ink`縁＋3D影、押下で沈む。テキストは白・ドット文字。
- **panel**: クリーム面＋`ink`太縁＋ハード3D影。モーダル/ボードの基本。
- **commandIcon**: 56px の**角丸四角タイル**。フラット単色（コマンド毎の識別色）＋**白の自作ピクセルアイコン（32×32, crispEdges）**。光沢・グラデ・真円は使わない。
- **numberHero**: クリーム/金のバッジに大きな赤い等幅数字（白縁＋段差影）。手応え・スコアに。
- **アイコン全般**: 絵文字ではなく**自作ピクセルアート（32×32, 1px自動アウトライン）**を基本とする。`images/icons/*.svg`。

## Do's and Don'ts
- **Do**: ink を骨格に据える / 種別・グレードの配色を横断で統一 / 表示=ドット文字・本文=可読フォントの使い分け / 3D影＋押下沈みで手触りを出す / 1画面に収める。
- **Don't**: `100vh` を使う（→`100dvh`） / 真円のアイコンタイル / ガラス光沢の多用 / 流れる/長い文章にドット文字 / 種別色をバラバラに使う / 絵文字をそのままUIアイコンにする。

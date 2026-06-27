# 矢田 マスターパーツ（原義データ）

このパーツの合成で着せ替え（表情・動き）を作る。一度作った固定パーツは二度と生成し直さない
＝色味・線のドリフトが起きない。

## 仕様
- **キャンバス：1264×843（全パーツ共通）** … そのまま (0,0) で重ねれば位置が合う。
- **重ね順 (z, 背面→前面)**：`yada_torso.png` → `yada_arms.png` → `yada_outline2.png` → `yada_eyes_<expr>.png`
- 4層を重ねると `yada_master.png` と画素差ゼロで再構成できることを検証済み（2026-06-27）。

## 現行パーツ一覧（2026-06-27 セット。`yada_master.png` から切り出し）
| ファイル | 層 | 内容 | 役割 |
|---|---|---|---|
| `yada_master.png` | — | フルボディ基準画像（本物の透過、市松除去済み） | 原義データ・座標の基準 |
| `yada_torso.png` | body | 胴体（スーツ＋脚＋靴。頭なし・腕なし） | 固定 |
| `yada_arms.png` | arms | 両袖＋手（左右まとめて1枚、矩形切り出し） | 固定（今のポーズ専用） |
| `yada_outline2.png` | head | 頭＋髪＋耳＋素顔（目+眉なし。首から上、y<=412で輪郭線にて頭部とカット） | 固定 |
| `yada_noeyes.png` | — | フルボディで目+眉だけ肌色消去（表情合成の中間素材。`tools/make_expression.ps1`が参照） | 中間生成物 |
| `yada_eyes_base.png` | eyes | 目+眉（標準・master由来） | 表情キー `base` |
| `yada_eyes_warai.png` | eyes | 目+眉（閉じ笑顔。fal.ai生成→整列抽出） | 表情キー `warai` |
| `yada_eyes_tsukkomi.png` | eyes | 目+眉（怒り・吊り眉。fal.ai生成） | 表情キー `tsukkomi` |
| `yada_eyes_odoroki.png` | eyes | 目+眉（驚き・見開き。fal.ai生成） | 表情キー `odoroki`（ゲーム未使用・予備） |
| `yada_eyes_suberi.png` | eyes | 目+眉（困り・八の字眉。fal.ai生成） | 表情キー `suberi` |

表情パーツの抽出範囲（master座標、目+眉ボックス）：x[490..790] y[198..292]。口・鼻ゾーンには一切触れないため、鼻口の誤生成が原理的に起きない（パワプロ＝鼻口なし準拠）。

生成・合成のやり方は [`tools/dechecker.ps1`](../../tools/dechecker.ps1)（市松透過→本物透過）と [`tools/make_expression.ps1`](../../tools/make_expression.ps1)（fal.ai出力→整列→目+眉抽出→ベース合成）を参照。

## レガシー（前バージョンの素材。別キャラ画像由来・現行セットとは非連結）
| ファイル | 内容 |
|---|---|
| `yada_body.png` / `yada_head.png` | 旧パーツ分離の試作（手切り）。現行の torso/outline2 とは別画像由来 |
| `yada_outline.png` | 別アップロード画像から市松除去した輪郭枠（yada_master とは別キャラ画像） |

## 注意
- 元データが市松模様の偽透過（JPG/手切りPNG由来）の場合は `tools/dechecker.ps1` で本物のPNG透過に変換すること。
- **今後のパーツは PNG（本物の透過）で書き出すこと**（JPGはロス劣化＋市松焼き込みのため非推奨）。
- 同一キャンバス・同一スケールを保つこと（位置合わせのため）。
- 腕が胴体の前を横切る新ポーズを作る場合は、`yada_torso.png` の腕が隠れる範囲をfal.aiインペイントで補完する必要がある（今の直立ポーズは腕と胴体が重ならないため不要だった）。

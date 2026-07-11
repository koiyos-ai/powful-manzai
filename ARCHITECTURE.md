# ARCHITECTURE ─ パワフル漫才 技術設計図

> **今後の実装の技術的な正本**。画面構成・データスキーマ・新規エンジンの仕様を定義する。
> 工程は [`ROADMAP.md`](ROADMAP.md)、ゲーム仕様は `00〜05_*.md` / `SCORING.md`、UIは `DESIGN.md` を参照。
> 新しい技術要素(エンジン・スキーマ)は**実装前に本書へ追記**する。

最終更新: 2026-07-04(§9 エンジン移行対応方針を追加)

---

## 1. 技術方針(確定)

- **二段構え(2026-07-04確定)**: 現行HTML版は**試作(v1.0)=遊べる仕様書**。最終完全版(v2.0)はゲームエンジン(Godot 4.x推奨/Unity対案)へ移植する(`ROADMAP §2.0` / 本書§9)。以下の方針はHTML版(v1.0)のもの。
- **スタック**: HTML / CSS / Vanilla JS / WebAudio。ビルド工程なし・フレームワークなし。
- **画面 = 1HTML**。画面間の状態共有は localStorage(`pm_*`)のみ。サーバ不要・完全静的。
- **対象**: iPhone Safari 優先(縦持ち・100dvh・タッチ)。PC ブラウザは開発用。
- **共有コードの扱い**: 現状は各HTMLに必要関数をコピーして自己完結(単一HTML主義)。
  Phase 1 でシナリオ/イベントエンジンを追加する際、**データとエンジンのみ `js/` に切り出して `<script src>` で共有**する(下記 §4)。UI/ゲームロジックは引き続き各HTML内。
  - 理由: 台本・イベントは全画面から量が大きく共有されるため、コピー同期は破綻する。逆にUIまで共通化すると単一HTMLの見通しの良さを失う。

## 2. 画面構成と遷移

```
index.html(タイトル)
 ├─→ success-play.html(育成・ハブ画面)
 │     ├─→ neta-builder.html(ネタ構成)     … enterKousei() / 戻りは history.back()
 │     └─→ manzai-play.html(本番モード)    … pm_honban を積んで遷移
 │           └─→ success-play.html         … pm_result を積んで自動帰還
 ├─→ manzai-play.html(単体・フリープレイ)
 └─→ neta-builder.html(単体)
```

- **本番往復プロトコル**(実装済み・変更時は両側を同時改修):
  1. 育成側: `pm_honban = {kind:"theater"|"award", round?, ...}` を set → `location.href="manzai-play.html"`
  2. 漫才側: 起動時に `pm_honban` を読む。終演時 `pm_result = {kind, acc, score, ...}` を set → 育成へ戻る
  3. 育成側: 起動時 `maybeApplyHonbanResult()` が `pm_result` を消費(読んだら即削除)
- 新画面を足す場合もこの「**行きはリクエスト、帰りはリザルト、受信側が消費削除**」の形を踏襲する。

## 3. データスキーマ(localStorage)

### 3.1 現行キー

| キー | 書き手 | 読み手 | 内容 |
|------|--------|--------|------|
| `pm_save` | success | success | 育成状態一式(§3.2) |
| `pm_parts` | success | neta-builder | 所持パーツ配列 |
| `pm_lineup` | neta-builder | manzai-play | 9枠の打線(譜面の元) |
| `pm_honban` | success | manzai-play | 本番リクエスト(消費削除)。`{kind,turn,startTemp,round?}`。`startTemp`=人気連動の開始温度(round(pop×0.25)、P2-01) |
| `pm_result` | manzai-play | success | 本番リザルト(消費削除) |

### 3.2 `pm_save` 中核フィールド(現行)

```js
{ turn, hp, hpMax, idea, money, pop, trust, m1Alive,
  m1Best,         // M-1で突破した最高ラウンドidx(3年間通し・-1=未突破)。人気ボーナスは更新時のみ(01_SUCCESS §6.1)
  honbanPending,  // 出番日に行動済み・タップ待ちで舞台へ出発前(リロードで再開。01_SUCCESS §5.4)
  abil:{ワード,トーク,リアクション,エンタメ,メンタル},  // 0..100
  parts:[{kind,pow,tag,rare?}...], lineup, combos:[...] }
```

### 3.3 スキーマ拡張の規約(Phase 1 で導入)

- `pm_save` に **`v`(スキーマ版数, int)** を追加。ロード時 `migrate(save)` で旧版を順送り変換。フィールド追加は「デフォルト値を与えるだけ」の後方互換を基本とする。
- **`pm_flags`**(新設): シナリオ・イベントの発火記録。`{seen:{"S-00":1,...}, vars:{playerName:"", ...}}`
  周回で消えてよいもの。`newGame()` でクリア。
- **`pm_meta`**(新設): **周回をまたいで永続**する図鑑類。`{endings:{E01:1,...}, combos:{...}, runs:3}`
  `clearSave()` でも**消さない**。
- 消費削除キー(`pm_honban`/`pm_result`)は versioning 不要(揮発)。

## 4. 新規エンジン仕様(Phase 1 の中核)

### 4.1 シナリオエンジン(紙芝居)

台本(SCRIPTS.md)・イベント台本(EVENTS.md)を**データ駆動**で再生する共通再生機。

- **ファイル**: `js/scenario.js`(再生機) + `js/data/scripts.js`(S-00〜) + `js/data/events.js`(EV-01〜)
- **画面**: 育成画面内のオーバーレイとして実装(専用HTMLは作らない)。背景暗転+立ち絵+台詞窓。
- **台本データ形式**(1シーン = コマンド配列):

```js
{ id:"S-00", title:"約束",
  steps:[
    {bg:"street_night"},                       // 背景切替(なければ黒)
    {chara:"hero", face:"base", pos:"L"},      // 立ち絵表示(L/R/C)
    {say:"美咲", text:"ほんまに行くん?", face:"base"},   // 話者名+文字送り
    {say:"{player}", text:"10年で決めてくる。約束や。"},  // {player}=主人公名を展開
    {choice:[ {label:"頷く", goto:"A"}, {label:"茶化す", goto:"B"} ]},
    {label:"A"}, {eff:{trust:+5}},             // 効果適用(能力/資源/フラグ)
    {jump:"END"}, {label:"B"}, {eff:{idea:+3}},
    {label:"END"}, {unlock:"cmd_netazukuri"},  // アンロック等の特殊効果
  ] }
```

- **step語彙(初期セット)**: `bg / chara / hide / say / choice / label / jump / eff / unlock / se / wait`。
  足りない演出はまず既存語彙の組合せで表現し、増やすときは本書に追記。
- **効果(`eff`)の適用先**は `pm_save` のフィールド名と一致させる(`{pop:+3, money:-2000}`)。
- 文字送り・話者名表示・SEは既存の `typeText`/`blip` 系を再利用。
- **表情指定は表情差分の実アセット名と一致**(`base/warai/odoroki/suberi/tsukkomi`。§6)。

### 4.2 イベントエンジン(抽選)

- **発火タイミング**は3種(01_SUCCESS / EVENTS.md の区分に対応):
  1. **コマンド派生**: 遊ぶ/バイト等の実行時に一定確率でプールから抽選
  2. **週送り**: `advanceTurn()` 時の汎用ランダム枠
  3. **出番後**: 劇場出番の結果確定後
- **イベント定義**:

```js
{ id:"EV-10", pool:"week",           // 抽選プール(cmd:asobi / week / theater)
  once:false,                         // true=1周1回(pm_flags.seenで管理)
  cond:(S)=>S.year>=2 && S.pop>=30,   // 発生条件(省略可)
  weight:10,                          // 重み
  script:"EV-10" }                    // §4.1の台本IDへ委譲
```

- 抽選器は「条件を満たすものから重み付きで1件」。`once` 済みは除外。
- **メインシナリオ(S-xx)は抽選しない**。年間カレンダー(§4.4)に固定配置し、該当週の `advanceTurn()` で強制再生。

### 4.3 審査員システム(決勝・SCORING §7 の実装)

- `js/data/judges.js` に10名を定義: `{id, name, persona, weights:{軸5系統}, bias}`。
- 決勝開始時に5名をランダム選出し `pm_honban.judges` で漫才プレイへ渡す。
- 漫才プレイ側はプレイ結果の内訳(リズム/威力/タグ実績)を `pm_result.detail` で返し、**採点計算は育成側**で行う(SCORING の式の実装箇所を1箇所に保つ)。

### 4.4 年間カレンダー

- 3年×48週のうち、固定イベント(メインシナリオ・劇場出番・M-1ラウンド)を `js/data/calendar.js` の一表で管理する。「いつ何が起きるか」の設計確定(ROADMAP §1.5)後に実装。
- 現行の `isTheaterTurn()`/`m1RoundAt()` のハードコードはこの表へ吸収。

### 4.5 エンディング判定(04_STORY §7.2)

- `js/data/endings.js`: `[{id, cond:(S,result)=>bool, priority, title, script}]` を**上から評価**(優先度順・最初にマッチ)。
- 判定結果は `pm_meta.endings[id]=1` で永続化 → 図鑑UIはこれを表示。
- 現行 `openEnding()` の5分岐は初期データとして移植し、以後はデータ追加のみで拡充。

## 5. 得点計算の実装配置

| 計算 | 実装箇所 | 根拠 |
|------|----------|------|
| リズム判定(Perfect〜Miss) | manzai-play | 演奏そのもの |
| 笑い量(威力×リズム×タグ) | manzai-play | フレーム内演出に必要 |
| 出来(acc)・内部得点 | manzai-play → `pm_result` | 演奏の要約 |
| 人気/発想力/出演料への換算・M-1突破判定・審査員採点 | success-play | 育成状態(能力/人気/信頼)を参照するため |

> 原則: **「舞台の上」は漫才側、「舞台の外」は育成側**。同じ式を両側に書かない。

## 6. アセット規約

### 6.1 キャラ絵(確定パイプライン)

- 制作は `tools/PXART_PROCESS.md`(64×96テキストマップ・決定論・生成AI不要)に完全準拠。**鼻・口は描かない**。
- マスター: `_pxmap_<char>[_<expr>].txt`(git管理)。PNGは `tools/pxrender.ps1` で再生成可能な派生物。
- **表情セットは5種固定**: `base / warai / odoroki / suberi / tsukkomi`(シナリオエンジンの`face`と1:1)。
- ゲーム組込み時の配置: `images/px/<char>_<expr>.png`(Phase 4 で旧 `images/hero*.png` 等を置換)。
  `image-rendering: pixelated` で拡大表示。論理サイズは各画面のレイアウトに従う。

### 6.2 その他

- アイコンSVG: `images/icons/`。UIトークン(色・角丸・文字)は `DESIGN.md` が一次情報源。
- 音: BGMはWebAudio合成 or mp3(要fetch=静的サーバ必須)。SEは全てWebAudio合成(ファイル追加しない)。

### 6.3 背景(シナリオエンジンの`bg`) ─ 2026-07-06追加

- シナリオの`bg`ステップは**当面は色替えのみ**(`makeScenarioView`の`BG_COLORS`マップ)。Phase 4(P4-02c)で実背景画像に置き換える。
- 実装移行時の規約: `images/bg/<bgId>.png` を用意し、描画は「**画像があれば画像・無ければ従来の色にフォールバック**」にする(未作成IDでも破綻させない=段階移行可能)。`image-rendering:pixelated` でキャラと絵柄を統一。
- bg IDは `data/scripts.json` の`bg`値がそのままキー(現行: street_night/river_dusk/backstage/sepia_flashback/black)。**背景画像もエンジン非依存アセット**(§9.3の持ち越し対象)としてv2.0へそのまま渡す。
- レイヤー順(最背面→前面): 背景 → 立ち絵 → 台詞窓/選択肢。P1-02でユーザー確認済みの立ち絵・台詞窓の座標配置を壊さないこと。

## 7. 開発・検証の運用

- ローカル: `.serve.ps1` 等の静的サーバ(mp3 fetchのため `file://` 不可)。
- 実機確認: サーバ+cloudflaredトンネルでURL共有(毎回の確認フロー)。
- 確認用HTML(`*-check.html`等)は使い捨て。世代遅れになったら `_archive/` へ移す(gitignore済み)。
- 一時生成物は `_*` 接頭辞(gitignore済み)。例外: `_pxmap_*.txt` はマスターとしてgit管理。
- コミット単位は「1機能1コミット」。設計変更は md 更新 → 実装の順。

## 8. 既知の技術的リスク・宿題

- **localStorage容量**(5MB目安): セーブは小さいがドット絵をbase64で持たない(必ずPNGファイル参照)。
- **iOS Safariのオーディオ解禁**: 初回タップで `ensureAudio()` 必須(実装済みパターンを踏襲)。
- **Service Worker**(Phase 6): キャッシュ戦略は「プリキャッシュ+バージョン付け」。導入時に本書へ追記。
- **改行コード**: リポジトリはCRLF混在警告あり。`.gitattributes` 導入を Phase 5 で検討。

## 9. エンジン移行(完全版v2.0)対応方針 ─ 2026-07-04追加

最終完全版は **Godot 4.x(推奨)または Unity**(正式選定はROADMAP Phase 7-1)。移植コストを最小化するため、**Phase 1以降のHTML実装は以下の規約に従う**。移植時に書き直すのは「画面とエンジン層」だけにする。

### 9.1 データはJSON(コードにしない)
- §4 で `js/data/*.js` としていたデータファイルは **`data/*.json` に読み替える**(scripts/events/combos/judges/endings/tokusyu/calendar)。HTML側は起動時に `fetch` で読み、エンジン側も**同じファイルをそのまま読む**=データは移植不要。
- JSONには関数を書けないため、**発生条件は宣言的DSL**で書く:
  ```json
  "cond": { "year_gte": 2, "pop_gte": 30, "flag_not": "S-09", "trust_lt": 40 }
  ```
  評価器 `evalCond(cond, S, flags)` をJS(v1.0)とGDScript/C#(v2.0)の双方に実装する。**キーの語彙は本節が正本**(必要になったら追記: `<field>_gte / <field>_lte / <field>_lt / flag / flag_not` から開始)。
- 効果(`eff`)は既存の宣言形式(`{"idea": 5, "money": -2000}`)を維持。

### 9.2 ロジックは「mdの式+テストベクタ」で固定
- 得点計算・ガチャ分布・成長コスト・会場温度・リズム判定窓は、**設計md(SCORING等)の式を唯一の正**とし、`data/testvectors/*.json`(入力→期待出力の表)を用意する。
- **パリティの定義**: HTML版とエンジン版の両方がこのテストベクタを全通過すること(Phase 8-5のQA基準)。

### 9.3 アセットの中立性
- キャラ絵の正本は `_pxmap_*.txt`(テキストマップ)。PNG実寸書き出しはどのエンジンでも使用可(Godotはテクスチャのフィルタ無効=`image-rendering:pixelated`相当)。
- 背景画像(`images/bg/`, §6.3, Phase 4で作成)もエンジン非依存アセットとしてそのまま持ち越す。
- BGM/SE: HTML版はWebAudio合成。エンジン版は (a)合成ロジックを移植 (b)wav書き出しして素材化 のどちらかをPhase 7-4で決定。**譜面のタイミング定義(BPM・拍位置)はJSONで持ち**、音源実装に依存させない。

### 9.4 書き直す層/持ち越す層
| 層 | v2.0での扱い |
|---|---|
| DOM/CSSのUI・WebAudio実装・localStorage | **書き直し**(エンジンのUI/Audio/保存APIへ) |
| `data/*.json`・テストベクタ・ドット絵・設計md | **そのまま持ち越し** |
| セーブスキーマ(`pm_save`等, §3) | JSON構造は維持し**保存先だけ差し替え**(Godot: `user://save.json`) |

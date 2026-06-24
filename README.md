# パワフル漫才（仮）

> パワプロ「サクセス」をお笑い芸人に置き換えた **育成シミュレーション × リズムゲーム × ハクスラ的ネタ収集** のハイブリッド。
> スマホ（iPhone/Safari優先）・単一HTML / Vanilla JS / WebAudio で動作。最終目標は M-1風賞レースでの優勝。

このREADMEはリポジトリの**地図**です。設計の全体像は [`00_OVERVIEW.md`](00_OVERVIEW.md)（司令塔）を参照してください。

---

## 📁 リポジトリ構成

### 設計仕様書（Markdown）
| ファイル | 内容 |
|----------|------|
| [00_OVERVIEW.md](00_OVERVIEW.md) | **目次・司令塔**。概要/世界観/周回設計/TODO/設計判断の記録 |
| [01_SUCCESS.md](01_SUCCESS.md) | サクセス（育成ループ）・賞レース |
| [02_MANZAI_PLAY.md](02_MANZAI_PLAY.md) | 漫才プレイ＝リズムゲーム |
| [03_NETA.md](03_NETA.md) | 育成パラメータ・ネタ構成（打線）・コンボ |
| [04_STORY.md](04_STORY.md) | シナリオ・キャラ・エンディング図鑑（設計） |
| [05_ART.md](05_ART.md) | キャラ画像制作（立ち絵・表情差分・生成プロンプト） |
| [SCORING.md](SCORING.md) | 得点計算（威力×リズム×能力×コンボ）・審査員システム |
| [EVENTS.md](EVENTS.md) | 劇場出番後のランダムイベント台本集 |
| [SCRIPTS.md](SCRIPTS.md) | メインシナリオの脚本全文（台本） |
| [DESIGN.md](DESIGN.md) | **UIデザインシステムの一次情報源**（design.md形式：色/文字/余白/部品トークン＋指針）。全画面のUIはこれに従う |

### ゲーム画面（HTML・プロトタイプ）
| ファイル | 内容 |
|----------|------|
| `index.html` | 漫才リズムゲーム（タイトル＋本番＋リザルトの統合版） |
| `success-play.html` | **サクセス（育成）画面** ─ 紙芝居UI・コマンド・劇場出番・賞レース（開発中の主戦場） |
| `manzai-play.html` | 漫才プレイ（リズムゲーム）単体。譜面＝「1パーツ=1小節」方式 |
| `neta-builder.html` | ネタ構成（9枠の打線を組む）画面 |
| `manzai-music.html` | 楽曲デモ |
| `powerful_manzai_neta_builder_mobile.html` | ネタビルダーのモバイル試作 |

### 補助
| 場所 | 内容 |
|------|------|
| `research/` | 設計検証ツールとリサーチ（下記） |
| `images/` | 立ち絵（透過PNG）・コマンドSVGアイコン・元画像バックアップ（`original/`） |
| `archive/` | 旧統合版 `GAME_DESIGN.md`・旧プロト `prototype/`（参照用に保存） |
| `racing_the_high_noon_1.mp3` | リズムゲーム用BGM（BPM150） |

### research/（設計検証）
| ファイル | 内容 |
|----------|------|
| [research/gacha-tuner.html](research/gacha-tuner.html) | ネタガチャ傾斜＆発想力収支の**調整ツール**（スライダーで分布・3年到達見通しを可視化） |
| [research/neta-gacha-design.md](research/neta-gacha-design.md) | ネタガチャ／発想力サイクルの**設計メモ**（確定値・改訂方針） |
| [research/powerpro-success-ux.md](research/powerpro-success-ux.md) | パワプロ／パワポケ サクセスUXの**リサーチ**と観察結果 |

---

## ▶ 動かし方

各HTMLはブラウザで開けば動作します。ただし `manzai-play.html` / `index.html` は MP3 を `fetch` するため、`file://` 直開きだとブラウザによっては読み込めません。**簡易HTTPサーバー経由**が確実です（例: 任意の静的サーバーでこのフォルダを配信し、`success-play.html` 等にアクセス）。

---

## 🎯 現在の開発フォーカス

- **サクセス画面（`success-play.html`）のブラッシュアップ**：紙芝居演出・話者名・文字送りSE・能力サマリー等を実装済み。
- **ネタガチャ／発想力サイクルの設計**：`research/` で数値設計中（確定値は `00_OVERVIEW.md` 付録B と `research/neta-gacha-design.md`）。
- 次段階：発想力供給の数値確定 → `03_NETA.md` への正式反映 → ガチャのゲーム実装。

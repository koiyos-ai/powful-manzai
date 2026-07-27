# check_params.ps1 ─ 仕様汚染の自動検出
#
# 目的: AIの注意力に依存せず、リポジトリの仕様汚染を機械的に洗い出す。
#   CLAUDE.mdの規約(prose)は2回破られた実績があるため、
#   「守らせる」のではなく「破ったら必ず見える」状態を作る。
#
# 検出するもの:
#   1. 幽霊出典  … PARAMS.mdの「正本」列が指す節が、その設計mdに実在しない
#   2. 提案の実装 … 状態が「提案」(未承認)の行 = 実装の根拠にしてはならない値の一覧
#   3. 状態の集計 … 確定/仮/提案の内訳(提案が増え続けていないかの監視)
#   4. 書式違反  … 状態列が3値以外(移行中・設計中などの曖昧な状態が紛れ込んでいないか)
#
# 使い方: pwsh -File tools/check_params.ps1   (異常があれば終了コード1)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$paramsPath = Join-Path $root "PARAMS.md"

if (-not (Test-Path $paramsPath)) { Write-Output "PARAMS.md が見つかりません"; exit 1 }

# 設計mdの略記 -> 実ファイル
$DocMap = @{
  "00" = "00_OVERVIEW.md"; "01" = "01_SUCCESS.md"; "02" = "02_MANZAI_PLAY.md"
  "03" = "03_NETA.md";     "04" = "04_STORY.md";   "05" = "05_ART.md"
  "SCORING" = "SCORING.md"; "ARCHITECTURE" = "ARCHITECTURE.md"
  "EVENTS" = "EVENTS.md";   "SCRIPTS" = "SCRIPTS.md"; "DESIGN" = "DESIGN.md"
  "ROADMAP" = "ROADMAP.md"; "PLAYBOOK" = "PLAYBOOK.md"; "CAST" = "CAST.md"
}
$ValidStates = @("確定","仮","提案","廃止","廃止済み")

$lines = [System.IO.File]::ReadAllLines($paramsPath, [System.Text.Encoding]::UTF8)

$ghosts = @(); $proposals = @(); $badStates = @()
$counts = @{}
foreach($s in $ValidStates){ $counts[$s] = 0 }

foreach($line in $lines){
  if($line -notmatch '^\|') { continue }                 # 表の行だけ
  if($line -match '^\|\s*-+') { continue }               # 区切り行
  $cells = $line -split '\|'
  if($cells.Count -lt 6) { continue }                    # | 名 | 値 | 状態 | 日 | 正本 | = 6要素以上
  $name   = $cells[1].Trim()
  $state  = $cells[3].Trim()
  $source = $cells[5].Trim()
  if($name -eq "パラメータ" -or $name -eq "") { continue } # ヘッダ

  # --- 状態の正規化(太字マークを除去)
  $st = ($state -replace '\*','').Trim()
  # 「提案(…)」のような補足付きも先頭語で判定
  $stHead = ($st -split '[\(（]')[0].Trim()
  if($ValidStates -contains $stHead){ $counts[$stHead]++ }
  else { $badStates += "$name  → 状態『$st』" ; continue }

  if($stHead -eq "提案"){ $proposals += "$name" }

  # --- 幽霊出典の検査(確定/仮のみ。提案はコード由来を許容)
  if($stHead -ne "確定" -and $stHead -ne "仮"){ continue }
  $src = ($source -replace '\*','').Trim()
  if($src -eq "" -or $src -eq "─" -or $src -like "*コードのみ*" -or $src -like "*算出のみ*"){ continue }

  # `01 §5.4` `SCORING §3` `docs/SPRITE_SPEC.md` `02 §4.5`訂正注記 など複数記載に対応
  $refs = [regex]::Matches($src, '`([^`]+)`')
  foreach($m in $refs){
    $ref = $m.Groups[1].Value.Trim()
    # ファイル直指定
    if($ref -like "*.md"){
      $p = Join-Path $root $ref
      if(-not (Test-Path $p)){ $ghosts += "$name  → ファイル無し: $ref" }
      continue
    }
    # 「略記 §番号」形式
    if($ref -match '^([0-9A-Za-z_]+)\s*§\s*([0-9]+(?:\.[0-9]+)*)'){
      $doc = $Matches[1]; $sec = $Matches[2]
      if(-not $DocMap.ContainsKey($doc)){ $ghosts += "$name  → 未知の略記: $ref"; continue }
      $p = Join-Path $root $DocMap[$doc]
      if(-not (Test-Path $p)){ $ghosts += "$name  → ファイル無し: $($DocMap[$doc])"; continue }
      $body = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
      # 見出し「### 4.5」「## 3.」または本文中の「§4.5」で節の実在を確認
      $secEsc = [regex]::Escape($sec)
      $hit = ($body -match "(?m)^#{2,4}\s*$secEsc[\s\.]") -or ($body -match "§\s*$secEsc")
      if(-not $hit){ $ghosts += "$name  → 節が実在しない: $ref" }
    }
  }
}

Write-Output "=== PARAMS.md 汚染チェック ==="
Write-Output ""
Write-Output "[状態の集計]"
foreach($s in $ValidStates){ if($counts[$s] -gt 0){ Write-Output ("  {0,-6} {1,3} 件" -f $s,$counts[$s]) } }

$ng = $false

Write-Output ""
if($badStates.Count -gt 0){
  $ng = $true
  Write-Output "[NG] 状態列が規定の3値(確定/仮/提案)以外: $($badStates.Count) 件"
  $badStates | ForEach-Object { Write-Output "  - $_" }
} else { Write-Output "[OK] 状態列は全て規定値" }

Write-Output ""
if($ghosts.Count -gt 0){
  $ng = $true
  Write-Output "[NG] 幽霊出典(正本に実在しない節を指している): $($ghosts.Count) 件"
  $ghosts | ForEach-Object { Write-Output "  - $_" }
} else { Write-Output "[OK] 幽霊出典なし(確定/仮の出典は全て実在)" }

Write-Output ""
Write-Output "[要承認] 状態が『提案』= 未承認のまま実装の根拠にできない値: $($proposals.Count) 件"
$proposals | ForEach-Object { Write-Output "  - $_" }
Write-Output "  ※提案が実装済みでも直ちにNGではないが、ユーザー承認を得て確定/仮へ昇格させること"

Write-Output ""
if($ng){ Write-Output "=== 異常あり。上記を是正すること ==="; exit 1 }
Write-Output "=== 異常なし ==="

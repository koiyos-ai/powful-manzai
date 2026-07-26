# px_recanvas_160.ps1 ─ 立ち絵スプライトを 160x192 に統一し、体の中心をキャンバス中央(x=80)に揃える
#
# 背景(2026-07-26):
#   手先の欠けを直した際に挙上ポーズだけ 112x192 -> 144x192 に広げたため、
#   「ポーズを切り替えるとキャンバス幅が変わる」構造になっていた。
#   幅が変わると、育成画面のような flex 横並びでは隣の要素が押されて位置がズレる。
#   (漫才プレイ側は絶対配置+体中心アンカーで回避していたが、使う場所が増えるたびに再発する)
#
# 対策: 全ポーズを同一キャンバス(160x192)にし、体の中心を常に x=80 に置く。
#   -> どのポーズでも幅が同じ = 切り替えても何も動かない。CSS側の補正が一切不要になる。
#
# 「体の中心」の定義: 最下端から20行(脚・靴)の水平中心。腕は動くが脚は動かないため、
#   これがポーズ間で一貫した基準になる。絵そのものは変更せず、平行移動のみ行う。

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$PxDir  = Join-Path $PSScriptRoot "..\images\px"
$NewW   = 160
$NewH   = 192
$CenterX = 80        # 体の中心を置く座標
$LegRows = 20        # 体中心の算出に使う最下端からの行数

$targets = @("hero_base","hero_upL","hero_upR","yada_base","yada_upL","yada_upR")

function Get-BodyCenter([System.Drawing.Bitmap]$img){
  # 最下端(不透明ピクセルがある最後の行)
  $bot = -1
  for($y=$img.Height-1; $y -ge 0; $y--){
    for($x=0; $x -lt $img.Width; $x++){
      if($img.GetPixel($x,$y).A -gt 0){ $bot=$y; break }
    }
    if($bot -ne -1){ break }
  }
  if($bot -lt 0){ return $null }
  # 最下端から LegRows 行の水平範囲
  $l=99999; $r=-1
  for($y=[Math]::Max(0,$bot-($LegRows-1)); $y -le $bot; $y++){
    for($x=0; $x -lt $img.Width; $x++){
      if($img.GetPixel($x,$y).A -gt 0){
        if($x -lt $l){ $l=$x }
        if($x -gt $r){ $r=$x }
      }
    }
  }
  if($r -lt 0){ return $null }
  return [PSCustomObject]@{ Center=(($l+$r)/2.0); Left=$l; Right=$r; Bottom=$bot }
}

function Get-ContentBounds([System.Drawing.Bitmap]$img){
  $l=99999; $r=-1; $t=-1; $b=-1
  for($y=0; $y -lt $img.Height; $y++){
    for($x=0; $x -lt $img.Width; $x++){
      if($img.GetPixel($x,$y).A -gt 0){
        if($t -eq -1){ $t=$y }
        $b=$y
        if($x -lt $l){ $l=$x }
        if($x -gt $r){ $r=$x }
      }
    }
  }
  return [PSCustomObject]@{ L=$l; R=$r; T=$t; B=$b }
}

Write-Output "=== 160x192 統一 (体中心 x=$CenterX) ==="
$fail = $false

foreach($name in $targets){
  $path = Join-Path $PxDir "$name.png"
  if(-not (Test-Path $path)){ Write-Output "  $name : ファイルなし - スキップ"; continue }

  $img = [System.Drawing.Bitmap]::new($path)
  $bc  = Get-BodyCenter $img
  $cb  = Get-ContentBounds $img
  if($null -eq $bc){ Write-Output "  $name : 不透明ピクセルなし - スキップ"; $img.Dispose(); continue }

  # 体中心が CenterX に来るような平行移動量(整数)。縦は下端を揃える(元と同じ最下端yを維持)
  $dx = [int][Math]::Round($CenterX - $bc.Center)
  $dy = 0

  $newL = $cb.L + $dx
  $newR = $cb.R + $dx
  if($newL -lt 0 -or $newR -gt ($NewW-1)){
    Write-Output ("  {0,-10} !! はみ出す: 移動後x=[{1}..{2}] (許容0..{3})" -f $name,$newL,$newR,($NewW-1))
    $fail = $true; $img.Dispose(); continue
  }

  $out = [System.Drawing.Bitmap]::new($NewW,$NewH,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  for($y=0; $y -lt $NewH; $y++){
    $sy = $y - $dy
    if($sy -lt 0 -or $sy -ge $img.Height){ continue }
    for($x=0; $x -lt $NewW; $x++){
      $sx = $x - $dx
      if($sx -lt 0 -or $sx -ge $img.Width){ continue }
      $out.SetPixel($x,$y,$img.GetPixel($sx,$sy))
    }
  }
  $img.Dispose()

  # GDI+は読込元と同じパスへ保存できないため一時ファイル経由
  $tmp = Join-Path $PxDir "_tmp_$name.png"
  $out.Save($tmp,[System.Drawing.Imaging.ImageFormat]::Png)
  $out.Dispose()
  Copy-Item $tmp $path -Force
  Remove-Item $tmp

  Write-Output ("  {0,-10} 体中心{1,5:F1} -> 平行移動{2,4} -> 160x192 体中心{3}" -f `
    $name,$bc.Center,$dx,$CenterX)
}

if($fail){ Write-Output "`n!! はみ出しがあるため中断した項目があります"; exit 1 }

Write-Output "`n=== 検証: 全ファイルの体中心が $CenterX に揃ったか ==="
foreach($name in $targets){
  $path = Join-Path $PxDir "$name.png"
  if(-not (Test-Path $path)){ continue }
  $img = [System.Drawing.Bitmap]::new($path)
  $bc  = Get-BodyCenter $img
  $cb  = Get-ContentBounds $img
  $ok  = [Math]::Abs($bc.Center - $CenterX) -le 0.5
  Write-Output ("  {0,-10} {1}x{2} 体中心={3,5:F1} 内容x=[{4,3}..{5,3}] 下端y={6} {7}" -f `
    $name,$img.Width,$img.Height,$bc.Center,$cb.L,$cb.R,$cb.B,$(if($ok){"OK"}else{"NG"}))
  $img.Dispose()
}

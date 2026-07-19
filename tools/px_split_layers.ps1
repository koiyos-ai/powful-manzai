# px_split_layers.ps1 - split the base sprite into per-part transparent layers using
# the FINALIZED dot DB, plus pose-swap group layers. Verifies that recomposing all
# part layers reproduces the base pixel-perfectly.
# Output: parts_px/hero/<part>.png (24) + parts_px/hero/groups/<group>.png (5)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$W=352; $H=192

$outDir = Join-Path $root "parts_px\hero"
$grpDir = Join-Path $outDir "groups"
New-Item -ItemType Directory -Force $outDir | Out-Null
New-Item -ItemType Directory -Force $grpDir | Out-Null

# ---------- load base pixels ----------
$img = [System.Drawing.Bitmap]::FromFile((Join-Path $root "_pxv2_hero_base.png"))
$rect = New-Object System.Drawing.Rectangle 0,0,$W,$H
$bd = $img.LockBits($rect,[System.Drawing.Imaging.ImageLockMode]::ReadOnly,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$pxB = New-Object byte[] ($bd.Stride*$H)
[System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0,$pxB,0,$pxB.Length)
$stB=$bd.Stride; $img.UnlockBits($bd); $img.Dispose()

# ---------- load part dot sets (DOTS + SHARED both included in the part's layer) ----------
function LoadPart([string]$file) {
  $set = New-Object 'System.Collections.Generic.HashSet[int]'
  foreach ($l in (Get-Content (Join-Path $root $file) -Encoding UTF8)) {
    $t=$l.Trim()
    if ($t -match "^y=(\d+):\s*([^@]*)") {
      $y=[int]$Matches[1]
      foreach ($tok in ($Matches[2].Trim() -split '\s+')) {
        if ($tok -match "^(\d+)-(\d+)$") { for($x=[int]$Matches[1];$x -le [int]$Matches[2];$x++){ [void]$set.Add($y*352+$x) } }
        elseif ($tok -match "^(\d+)$") { [void]$set.Add($y*352+[int]$Matches[1]) }
      }
    }
  }
  return ,$set
}

$partNames = (Get-ChildItem (Join-Path $root "_dots_*.txt") | ForEach-Object { $_.BaseName -replace '^_dots_','' })
$partSets = New-Object 'System.Collections.Generic.Dictionary[string,object]'
foreach ($p in $partNames) { $partSets[$p] = LoadPart "_dots_$p.txt" }

function SaveLayer($set, [string]$outPath) {
  $dst = New-Object System.Drawing.Bitmap $W,$H,([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $bdD = $dst.LockBits((New-Object System.Drawing.Rectangle 0,0,$W,$H),[System.Drawing.Imaging.ImageLockMode]::WriteOnly,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $pxD = New-Object byte[] ($bdD.Stride*$H)
  foreach ($i in $set) {
    $y=[math]::Floor($i/352); $x=$i%352
    $oB=$y*$stB+$x*4; $oD=$y*$bdD.Stride+$x*4
    $pxD[$oD]=$pxB[$oB]; $pxD[$oD+1]=$pxB[$oB+1]; $pxD[$oD+2]=$pxB[$oB+2]; $pxD[$oD+3]=$pxB[$oB+3]
  }
  [System.Runtime.InteropServices.Marshal]::Copy($pxD,0,$bdD.Scan0,$pxD.Length)
  $dst.UnlockBits($bdD)
  $dst.Save($outPath,[System.Drawing.Imaging.ImageFormat]::Png)
  $dst.Dispose()
}

# ---------- per-part layers ----------
foreach ($p in $partNames) {
  SaveLayer $partSets[$p] (Join-Path $outDir "$p.png")
}
Write-Host "wrote $($partNames.Count) part layers to parts_px/hero/"

# ---------- group layers (pose-swap building blocks) ----------
$groups = New-Object 'System.Collections.Generic.Dictionary[string,string[]]'
$groups["head"]   = @("hair","face","brow_L","brow_R","eye_L","eye_R")
$groups["torso"]  = @("shirt_collar","tie","lapel_L","lapel_R","jacket_body","placket","button","flap_L","flap_R")
$groups["arm_L"]  = @("sleeve_L","cuff_L","fist_L")
$groups["arm_R"]  = @("sleeve_R","cuff_R","fist_R")
$groups["legs"]   = @("trousers","shoe_L","shoe_R")
foreach ($g in $groups.Keys) {
  $u = New-Object 'System.Collections.Generic.HashSet[int]'
  foreach ($p in $groups[$g]) { foreach ($i in $partSets[$p]) { [void]$u.Add($i) } }
  SaveLayer $u (Join-Path $grpDir "$g.png")
  Write-Host ("group {0}: {1} dots" -f $g,$u.Count)
}

# ---------- recompose verification ----------
$union = New-Object 'System.Collections.Generic.HashSet[int]'
foreach ($p in $partNames) { foreach ($i in $partSets[$p]) { [void]$union.Add($i) } }
$mismatch=0; $missing=0; $extra=0
for ($y=0;$y -lt $H;$y++) { for ($x=0;$x -lt $W;$x++) {
  $i=$y*352+$x
  $oB=$y*$stB+$x*4
  $baseOpq = ($pxB[$oB+3] -ge 128)
  $inUnion = $union.Contains($i)
  if ($baseOpq -and -not $inUnion) { $missing++ }
  if (-not $baseOpq -and $inUnion) { $extra++ }
}}
Write-Host ("recompose check: union={0} dots, missing={1}, extra={2}" -f $union.Count,$missing,$extra)
if ($missing -eq 0 -and $extra -eq 0) { Write-Host "VERIFIED: layers recompose the base exactly (colors are copied 1:1 by construction)." }

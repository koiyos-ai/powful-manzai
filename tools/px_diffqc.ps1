# px_diffqc.ps1 - part-aware diff QC using the finalized dot DB.
# Compares a variant sprite against _pxv2_hero_base.png and classifies every changed
# dot by which part it belonged to in the base. Catches out-of-scope edits mechanically
# (the class of bug that once broke the collar during arm edits).
# Usage: powershell -File tools\px_diffqc.ps1 -variant _pxv2_hero_handupR6.png -declared "sleeve_R,cuff_R,fist_R,jacket_body" -out _qc_R6
param(
  [string]$variant,
  [string]$declared,   # comma-separated part names expected to change
  [string]$out = "_qc"
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$W=352; $H=192
$declaredSet = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($d in ($declared -split ',')) { [void]$declaredSet.Add($d.Trim()) }

function LoadPx([string]$p) {
  $img = [System.Drawing.Bitmap]::FromFile((Join-Path $root $p))
  $rect = New-Object System.Drawing.Rectangle 0,0,$img.Width,$img.Height
  $bd = $img.LockBits($rect,[System.Drawing.Imaging.ImageLockMode]::ReadOnly,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $px = New-Object byte[] ($bd.Stride*$img.Height)
  [System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0,$px,0,$px.Length)
  $st=$bd.Stride; $img.UnlockBits($bd); $img.Dispose()
  return @($px,$st)
}
$b = LoadPx "_pxv2_hero_base.png"; $pxB=$b[0]; $stB=$b[1]
$v = LoadPx $variant;              $pxV=$v[0]; $stV=$v[1]

# owner map from dots files (first owner wins for reporting; shared dots list both)
$owner = New-Object 'object[]' ($W*$H)
foreach ($f in (Get-ChildItem (Join-Path $root "_dots_*.txt") | Sort-Object Name)) {
  $part = $f.BaseName -replace '^_dots_',''
  foreach ($l in (Get-Content $f.FullName -Encoding UTF8)) {
    $t=$l.Trim()
    if ($t -match "^y=(\d+):\s*([^@]*)") {
      $y=[int]$Matches[1]
      foreach ($tok in ($Matches[2].Trim() -split '\s+')) {
        $a=-1;$b2=-1
        if ($tok -match "^(\d+)-(\d+)$") { $a=[int]$Matches[1]; $b2=[int]$Matches[2] }
        elseif ($tok -match "^(\d+)$") { $a=[int]$Matches[1]; $b2=$a }
        if ($a -lt 0) { continue }
        for ($x=$a;$x -le $b2;$x++) {
          $i=$y*352+$x
          if ($null -eq $owner[$i]) { $owner[$i] = New-Object System.Collections.ArrayList }
          if (-not $owner[$i].Contains($part)) { [void]$owner[$i].Add($part) }
        }
      }
    }
  }
}

$perPart = New-Object 'System.Collections.Generic.Dictionary[string,int]'
$added=0; $addedList = New-Object System.Collections.ArrayList
$suspect = New-Object System.Collections.ArrayList
$okCnt=0
$dst = New-Object System.Drawing.Bitmap $W,$H
for ($y=0;$y -lt $H;$y++) { for ($x=0;$x -lt $W;$x++) {
  $oB=$y*$stB+$x*4; $oV=$y*$stV+$x*4
  $aB = ($pxB[$oB+3] -ge 128); $aV = ($pxV[$oV+3] -ge 128)
  $same = $true
  if ($aB -ne $aV) { $same=$false }
  elseif ($aB) {
    $dr=[math]::Abs([int]$pxB[$oB+2]-[int]$pxV[$oV+2])+[math]::Abs([int]$pxB[$oB+1]-[int]$pxV[$oV+1])+[math]::Abs([int]$pxB[$oB]-[int]$pxV[$oV])
    if ($dr -gt 0) { $same=$false }
  }
  # render bg: variant grayscale
  if ($aV) {
    $gray=[int](([int]$pxV[$oV+2]+[int]$pxV[$oV+1]+[int]$pxV[$oV])/3)
    $dst.SetPixel($x,$y,[System.Drawing.Color]::FromArgb(255,$gray,$gray,$gray))
  }
  if ($same) { continue }
  if (-not $aB) {
    # added dot (new drawing on background) - always fine
    $added++
    $dst.SetPixel($x,$y,[System.Drawing.Color]::FromArgb(255,0,180,255))
    continue
  }
  $ol = $owner[$y*352+$x]
  $tag = "(unowned)"
  $isDeclared = $false
  if ($null -ne $ol) {
    $tag = ($ol -join "+")
    foreach ($p in $ol) { if ($declaredSet.Contains($p)) { $isDeclared=$true } }
  }
  if ($perPart.ContainsKey($tag)) { $perPart[$tag]++ } else { $perPart[$tag]=1 }
  if ($isDeclared) {
    $okCnt++
    $dst.SetPixel($x,$y,[System.Drawing.Color]::FromArgb(255,0,220,80))
  } else {
    [void]$suspect.Add(@($x,$y,$tag))
    $dst.SetPixel($x,$y,[System.Drawing.Color]::FromArgb(255,255,0,0))
  }
}}

Write-Host "=== part-aware diff QC: $variant ==="
Write-Host ("declared parts: {0}" -f ($declaredSet -join ","))
Write-Host ("added dots (new on background): {0}" -f $added)
Write-Host ("changed base dots within declared parts: {0}" -f $okCnt)
Write-Host ("changed base dots OUTSIDE declared parts (suspect): {0}" -f $suspect.Count)
Write-Host "changes by base part:"
foreach ($kv in ($perPart.GetEnumerator() | Sort-Object Value -Descending)) { Write-Host ("  {0} = {1}" -f $kv.Key,$kv.Value) }
if ($suspect.Count -gt 0) {
  Write-Host "first suspects:"
  $suspect | Select-Object -First 20 | ForEach-Object { Write-Host ("  ({0},{1}) {2}" -f $_[0],$_[1],$_[2]) }
}
$big = New-Object System.Drawing.Bitmap ($W*4),($H*4)
$g2=[System.Drawing.Graphics]::FromImage($big)
$g2.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g2.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::Half
$g2.DrawImage($dst,(New-Object System.Drawing.Rectangle 0,0,($W*4),($H*4)))
$g2.Dispose()
$big.Save((Join-Path $root "$out.png"),[System.Drawing.Imaging.ImageFormat]::Png)
$big.Dispose(); $dst.Dispose()
Write-Host "wrote $out.png (green=declared change, red=suspect, blue=new drawing)"

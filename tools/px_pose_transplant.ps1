# px_pose_transplant.ps1 - Transplant pose changes from hero onto another character.
# For each pixel: if hero_base == hero_pose -> use target_base (unchanged area)
#                 if hero_base != hero_pose -> color-remap hero->target palette (changed area)
# This preserves the target's unique features (face, hair) while transplanting arm movements.
param(
  [string]$heroBase = "images\px\hero_base.png",
  [string]$heroPose = "images\px\hero_upL.png",
  [string]$targetBase = "images\px\yada_base.png",
  [string]$out = "_pxv2_yada_upL.png",
  [string]$srcChar = "hero",
  [string]$dstChar = "yada"
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root $heroBase))) { $root = (Get-Location).Path }

# Load palettes
. (Join-Path $root "tools\pxpalettes.ps1")
$srcPal = $PXPAL[$srcChar]
$dstPal = $PXPAL[$dstChar]

# Build color remap table: for each src palette RGB, find the equivalent dst palette symbol and RGB
# Symbol mapping: K->K, H->H, 2->2, S->S, 1->1, W->W, 9->9, T->T, C->C, 5->5, R->B, 3->4
$symbolMap = @{ 'K'='K'; 'H'='H'; '2'='2'; 'S'='S'; '1'='1'; 'W'='W'; '9'='9'; 'T'='T'; 'C'='C'; '5'='5'; 'R'='B'; '3'='4' }

# Build RGB->RGB remap (src color -> dst color)
$remapR = @{}; $remapG = @{}; $remapB = @{}
foreach ($sk in $srcPal.Keys) {
  $sv = $srcPal[$sk]
  if ($sv[3] -eq 0) { continue }
  $srcKey = "$($sv[0]),$($sv[1]),$($sv[2])"
  $dk = $sk
  if ($symbolMap.ContainsKey($sk)) { $dk = $symbolMap[$sk] }
  if ($dstPal.ContainsKey($dk)) {
    $dv = $dstPal[$dk]
    $remapR[$srcKey] = $dv[0]; $remapG[$srcKey] = $dv[1]; $remapB[$srcKey] = $dv[2]
  }
}
Write-Host "remap entries: $($remapR.Count)"

function LoadBmp([string]$path) {
  $o = [System.Drawing.Bitmap]::FromFile($path)
  $b = New-Object System.Drawing.Bitmap $o.Width, $o.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($b); $g.DrawImage($o,0,0,$o.Width,$o.Height); $g.Dispose(); $o.Dispose()
  return $b
}
function GetBytes([System.Drawing.Bitmap]$bmp) {
  $r = New-Object System.Drawing.Rectangle 0,0,$bmp.Width,$bmp.Height
  $d = $bmp.LockBits($r,[System.Drawing.Imaging.ImageLockMode]::ReadOnly,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $arr = New-Object byte[] ($d.Stride*$bmp.Height)
  [System.Runtime.InteropServices.Marshal]::Copy($d.Scan0,$arr,0,$arr.Length)
  $bmp.UnlockBits($d)
  return @{ bytes=$arr; stride=$d.Stride; w=$bmp.Width; h=$bmp.Height }
}

$hbBmp = LoadBmp (Join-Path $root $heroBase)
$hpBmp = LoadBmp (Join-Path $root $heroPose)
$tbBmp = LoadBmp (Join-Path $root $targetBase)

$hb = GetBytes $hbBmp; $hbBmp.Dispose()
$hp = GetBytes $hpBmp; $hpBmp.Dispose()
$tb = GetBytes $tbBmp; $tbBmp.Dispose()

$ww = $hb.w; $hh = $hb.h; $stride = $hb.stride
Write-Host "size: ${ww}x${hh}"

# Output = copy of target base
$outBytes = New-Object byte[] $tb.bytes.Length
[Array]::Copy($tb.bytes, $outBytes, $tb.bytes.Length)

$changed = 0; $kept = 0; $remapped = 0; $newdraw = 0
for ($y = 0; $y -lt $hh; $y++) {
  for ($x = 0; $x -lt $ww; $x++) {
    $o = $y * $stride + $x * 4
    $hbR = $hb.bytes[$o+2]; $hbG = $hb.bytes[$o+1]; $hbB = $hb.bytes[$o]; $hbA = $hb.bytes[$o+3]
    $hpR = $hp.bytes[$o+2]; $hpG = $hp.bytes[$o+1]; $hpB = $hp.bytes[$o]; $hpA = $hp.bytes[$o+3]
    # Same pixel in hero base and pose -> keep target base pixel
    if ($hbR -eq $hpR -and $hbG -eq $hpG -and $hbB -eq $hpB -and $hbA -eq $hpA) { $kept++; continue }
    $changed++
    # Hero pose pixel is transparent -> make output transparent
    if ($hpA -lt 128) {
      $outBytes[$o] = 0; $outBytes[$o+1] = 0; $outBytes[$o+2] = 0; $outBytes[$o+3] = 0
      continue
    }
    # Color-remap hero pose pixel to target palette
    $key = "$hpR,$hpG,$hpB"
    if ($remapR.ContainsKey($key)) {
      $outBytes[$o]   = $remapB[$key]
      $outBytes[$o+1] = $remapG[$key]
      $outBytes[$o+2] = $remapR[$key]
      $outBytes[$o+3] = 255
      $remapped++
    } else {
      # No exact match: find nearest dst palette color
      $bestD = [int]::MaxValue; $bestR = 0; $bestG = 0; $bestB2 = 0
      foreach ($dk in $dstPal.Keys) {
        $dv = $dstPal[$dk]; if ($dv[3] -eq 0) { continue }
        $dr = $hpR-$dv[0]; $dg = $hpG-$dv[1]; $db = $hpB-$dv[2]
        $d = $dr*$dr+$dg*$dg+$db*$db
        if ($d -lt $bestD) { $bestD=$d; $bestR=$dv[0]; $bestG=$dv[1]; $bestB2=$dv[2] }
      }
      $outBytes[$o] = $bestB2; $outBytes[$o+1] = $bestG; $outBytes[$o+2] = $bestR; $outBytes[$o+3] = 255
      $newdraw++
    }
  }
}
Write-Host "kept=$kept changed=$changed (remapped=$remapped nearest=$newdraw)"

# Write output
$dst = New-Object System.Drawing.Bitmap $ww, $hh, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$bd = $dst.LockBits((New-Object System.Drawing.Rectangle 0,0,$ww,$hh), [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
[System.Runtime.InteropServices.Marshal]::Copy($outBytes, 0, $bd.Scan0, $outBytes.Length)
$dst.UnlockBits($bd)
$dst.Save((Join-Path $root $out), [System.Drawing.Imaging.ImageFormat]::Png)

# 4x preview
$big = New-Object System.Drawing.Bitmap ($ww*4), ($hh*4)
$g2 = [System.Drawing.Graphics]::FromImage($big)
$g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g2.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$g2.DrawImage($dst, (New-Object System.Drawing.Rectangle 0,0,($ww*4),($hh*4)))
$g2.Dispose()
$bigPath = ($out -replace "\.png$", "_big.png")
$big.Save((Join-Path $root $bigPath), [System.Drawing.Imaging.ImageFormat]::Png)
$big.Dispose(); $dst.Dispose()
Write-Host "wrote $out and $bigPath"

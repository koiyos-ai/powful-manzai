# px_palmap.ps1 - Map a draft dot-art PNG to a character's fixed palette (from pxpalettes.ps1).
# Usage: powershell -ExecutionPolicy Bypass -File tools\px_palmap.ps1 -src _pxv2_yada_base.png -char yada -out _pxv2_yada_mapped.png
param(
  [string]$src = "_pxv2_yada_base.png",
  [string]$char = "yada",
  [string]$out = "_pxv2_yada_mapped.png"
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root $src))) { $root = (Get-Location).Path }

# Load palette
. (Join-Path (Split-Path -Parent $PSScriptRoot) "tools\pxpalettes.ps1") 2>$null
if (-not $PXPAL) { . (Join-Path (Get-Location).Path "tools\pxpalettes.ps1") }
$pal = $PXPAL[$char]
if (-not $pal) { Write-Error "unknown char: $char"; exit 1 }

# Build palette arrays (skip transparent)
$palKeys = New-Object System.Collections.ArrayList
$palR = New-Object System.Collections.ArrayList
$palG = New-Object System.Collections.ArrayList
$palB = New-Object System.Collections.ArrayList
foreach ($k in $pal.Keys) {
  $v = $pal[$k]
  if ($v[3] -eq 0) { continue }
  [void]$palKeys.Add($k)
  [void]$palR.Add($v[0])
  [void]$palG.Add($v[1])
  [void]$palB.Add($v[2])
}
Write-Host "palette '$char': $($palKeys.Count) opaque colors"

$srcPath = Join-Path $root $src
$outPath = Join-Path $root $out

$orig = [System.Drawing.Bitmap]::FromFile($srcPath)
$ww = $orig.Width; $hh = $orig.Height
$img = New-Object System.Drawing.Bitmap $ww, $hh, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g0 = [System.Drawing.Graphics]::FromImage($img)
$g0.DrawImage($orig, 0, 0, $ww, $hh)
$g0.Dispose(); $orig.Dispose()

$rect = New-Object System.Drawing.Rectangle 0, 0, $ww, $hh
$bd = $img.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$bytes = New-Object byte[] ($bd.Stride * $hh)
[System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $bytes, 0, $bytes.Length)
$stride = $bd.Stride

$mapped = 0
for ($y = 0; $y -lt $hh; $y++) {
  for ($x = 0; $x -lt $ww; $x++) {
    $o = $y * $stride + $x * 4
    $a = $bytes[$o+3]
    if ($a -lt 128) { $bytes[$o]=0; $bytes[$o+1]=0; $bytes[$o+2]=0; $bytes[$o+3]=0; continue }
    $r = [int]$bytes[$o+2]; $g = [int]$bytes[$o+1]; $b = [int]$bytes[$o]
    $bestJ = 0; $bestD = [int]::MaxValue
    for ($j = 0; $j -lt $palR.Count; $j++) {
      $dr = $r - $palR[$j]; $dg = $g - $palG[$j]; $db = $b - $palB[$j]
      $d = $dr*$dr + $dg*$dg + $db*$db
      if ($d -lt $bestD) { $bestD = $d; $bestJ = $j }
    }
    $bytes[$o]   = $palB[$bestJ]
    $bytes[$o+1] = $palG[$bestJ]
    $bytes[$o+2] = $palR[$bestJ]
    $bytes[$o+3] = 255
    $mapped++
  }
}

[System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $bd.Scan0, $bytes.Length)
$img.UnlockBits($bd)
$img.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)

# Also make 4x preview
$big = New-Object System.Drawing.Bitmap ($ww*4), ($hh*4)
$g2 = [System.Drawing.Graphics]::FromImage($big)
$g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g2.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$g2.DrawImage($img, (New-Object System.Drawing.Rectangle 0,0,($ww*4),($hh*4)))
$g2.Dispose()
$bigPath = $outPath -replace "\.png$", "_big.png"
$big.Save($bigPath, [System.Drawing.Imaging.ImageFormat]::Png)
$big.Dispose(); $img.Dispose()
Write-Host "mapped ${mapped} pixels to ${char} palette, wrote ${out} and preview"

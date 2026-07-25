# px_prefit.ps1 - Fit a character illustration onto a target canvas (4x of final dot size).
# Trims transparent padding, scales to fill target height, centers horizontally.
# Usage: powershell -ExecutionPolicy Bypass -File tools\px_prefit.ps1 -src images\yada_source.png -out _yada_prefit.png -tw 448 -th 768
param(
  [string]$src = "images\yada_source.png",
  [string]$out = "_yada_prefit.png",
  [int]$tw = 448,   # target width  (112 * 4)
  [int]$th = 768    # target height (192 * 4)
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root $src))) { $root = (Get-Location).Path }
$srcPath = Join-Path $root $src
$outPath = Join-Path $root $out

$img = [System.Drawing.Bitmap]::FromFile($srcPath)
$sw = $img.Width; $sh = $img.Height
Write-Host "source: ${sw}x${sh}"

# --- find opaque bounding box (trim transparent) ---
$minX = $sw; $minY = $sh; $maxX = 0; $maxY = 0
for ($y = 0; $y -lt $sh; $y++) {
  for ($x = 0; $x -lt $sw; $x++) {
    $px = $img.GetPixel($x, $y)
    if ($px.A -ge 128) {
      if ($x -lt $minX) { $minX = $x }
      if ($x -gt $maxX) { $maxX = $x }
      if ($y -lt $minY) { $minY = $y }
      if ($y -gt $maxY) { $maxY = $y }
    }
  }
}
$cw = $maxX - $minX + 1
$ch = $maxY - $minY + 1
Write-Host "opaque bbox: x=${minX}..${maxX} y=${minY}..${maxY} (${cw}x${ch})"

# --- scale to fill target height with small padding ---
$pad = [int]($th * 0.03)   # 3% padding top/bottom
$fitH = $th - $pad * 2
$scale = [double]$fitH / $ch
$newW = [int][math]::Round($cw * $scale)
$newH = [int][math]::Round($ch * $scale)
if ($newW -gt $tw) {
  $scale = [double]($tw - $pad * 2) / $cw
  $newW = [int][math]::Round($cw * $scale)
  $newH = [int][math]::Round($ch * $scale)
}
Write-Host "scale=${scale} -> ${newW}x${newH} on ${tw}x${th} canvas"

# --- crop source to bbox ---
$cropped = New-Object System.Drawing.Bitmap $cw, $ch
$gc = [System.Drawing.Graphics]::FromImage($cropped)
$gc.DrawImage($img, (New-Object System.Drawing.Rectangle 0, 0, $cw, $ch), $minX, $minY, $cw, $ch, [System.Drawing.GraphicsUnit]::Pixel)
$gc.Dispose()
$img.Dispose()

# --- draw onto target canvas, centered ---
$dst = New-Object System.Drawing.Bitmap $tw, $th, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$gd = [System.Drawing.Graphics]::FromImage($dst)
$gd.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$gd.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$ox = [int][math]::Round(($tw - $newW) / 2)
$oy = [int][math]::Round(($th - $newH) / 2)
$gd.DrawImage($cropped, (New-Object System.Drawing.Rectangle $ox, $oy, $newW, $newH))
$gd.Dispose()
$cropped.Dispose()

$dst.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
$dst.Dispose()
Write-Host "wrote ${out} (${tw}x${th}), char offset=(${ox},${oy})"

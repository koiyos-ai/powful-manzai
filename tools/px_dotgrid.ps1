# px_dotgrid.ps1 - per-dot coordinate-labeled zoom for user dot-picking
param(
  [int]$rx, [int]$ry, [int]$rw, [int]$rh,
  [string]$out = "_dotgrid.png",
  [int]$scale = 28
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$src = [System.Drawing.Bitmap]::FromFile((Join-Path $root "_pxv2_hero_base.png"))
$crop = New-Object System.Drawing.Bitmap $rw,$rh
$g = [System.Drawing.Graphics]::FromImage($crop)
$g.DrawImage($src,(New-Object System.Drawing.Rectangle 0,0,$rw,$rh),(New-Object System.Drawing.Rectangle $rx,$ry,$rw,$rh),[System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose(); $src.Dispose()

$marginL=3; $marginT=1
$big = New-Object System.Drawing.Bitmap (($rw+$marginL)*$scale),(($rh+$marginT)*$scale)
$gb = [System.Drawing.Graphics]::FromImage($big)
$gb.Clear([System.Drawing.Color]::White)
$gb.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$gb.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$gb.DrawImage($crop,(New-Object System.Drawing.Rectangle ($marginL*$scale),($marginT*$scale),($rw*$scale),($rh*$scale)))

$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(140,0,220,255)),1
$font = New-Object System.Drawing.Font("Consolas",8)
$brushX = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255,220,0,0))
$brushY = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255,0,90,220))

for ($gx=0; $gx -le $rw; $gx++) {
  $px = ($marginL+$gx)*$scale
  $gb.DrawLine($pen, $px,$marginT*$scale,$px,($rh+$marginT)*$scale)
  if ($gx -lt $rw) { $gb.DrawString(($rx+$gx).ToString(), $font, $brushX, $px+2, 2) }
}
for ($gy=0; $gy -le $rh; $gy++) {
  $py = ($marginT+$gy)*$scale
  $gb.DrawLine($pen, $marginL*$scale,$py,($rw+$marginL)*$scale,$py)
  if ($gy -lt $rh) { $gb.DrawString(($ry+$gy).ToString(), $font, $brushY, 2, $py+2) }
}
$gb.Dispose()
$big.Save((Join-Path $root $out),[System.Drawing.Imaging.ImageFormat]::Png)
$big.Dispose(); $crop.Dispose()
Write-Host "wrote $out"

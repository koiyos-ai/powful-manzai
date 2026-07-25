# make_handup_v6.ps1 - fix v5's real defects found via pixel forensics + reference comparison:
#  1) missing outline along torso/underarm edge y111-136 (flatten leftover had no outline stroke -> looked like a jagged hole)
#  2) stray leftover cuff-decoration flecks at the OLD wrist position (~146-149,138-139) - orphaned since the old fist moved
#  3) stray leftover cuff-decoration flecks at the NEW fist's cuff junction (~121-124,64-65) - same origin, relocated by the fist-copy step
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$basePath = Join-Path $root "_pxv2_hero_handup5.png"

$src = [System.Drawing.Bitmap]::FromFile($basePath)
$w = $src.Width; $h = $src.Height
$dst = New-Object System.Drawing.Bitmap $w,$h,([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$gfx = [System.Drawing.Graphics]::FromImage($dst)
$gfx.DrawImage($src, 0, 0, $w, $h)
$gfx.Dispose(); $src.Dispose()

$rect = New-Object System.Drawing.Rectangle 0,0,$w,$h
$bd = $dst.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$px = New-Object byte[] ($bd.Stride * $h)
[System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $px, 0, $px.Length)
$st = $bd.Stride

function SetP([int]$xx,[int]$yy,[int]$rr,[int]$gg,[int]$bb) {
  if ($xx -lt 0 -or $xx -ge $w -or $yy -lt 0 -or $yy -ge $h) { return }
  $o = $yy*$st+$xx*4
  $px[$o]=[byte]$bb; $px[$o+1]=[byte]$gg; $px[$o+2]=[byte]$rr; $px[$o+3]=255
}
function ClearP([int]$xx,[int]$yy) {
  if ($xx -lt 0 -or $xx -ge $w -or $yy -lt 0 -or $yy -ge $h) { return }
  $o = $yy*$st+$xx*4
  $px[$o]=0; $px[$o+1]=0; $px[$o+2]=0; $px[$o+3]=0
}

$cK = @(8,8,8)
$cR = @(248,8,24)
$cW = @(248,248,248)

# === FIX 1: stroke the missing outline along the underarm/torso edge, y111-136 ===
# x-boundary per row, measured directly off the actual flatten-leftover edge (px_region grid dumps)
$boundary = @{
  111=148; 112=148; 113=147; 114=146; 115=146; 116=145; 117=145; 118=144;
  119=143; 120=143; 121=142; 122=142; 123=141; 124=141; 125=140; 126=140;
  127=139; 128=139; 129=138; 130=138; 131=137; 132=137; 133=137; 134=137;
  135=137; 136=137
}
foreach ($y in $boundary.Keys) {
  $bx = $boundary[$y]
  SetP $bx $y $cK[0] $cK[1] $cK[2]
}
Write-Host "fix1: outline stroked y111-136"

# === FIX 2: clean stray cuff-decoration flecks left at the OLD wrist position ===
SetP 146 138 $cR[0] $cR[1] $cR[2]
SetP 146 139 $cR[0] $cR[1] $cR[2]
SetP 147 139 $cR[0] $cR[1] $cR[2]
SetP 148 139 $cR[0] $cR[1] $cR[2]
SetP 149 139 $cR[0] $cR[1] $cR[2]
Write-Host "fix2: old-wrist stray flecks cleaned"

# === FIX 3: clean stray cuff-decoration flecks at the NEW fist's cuff junction ===
SetP 121 64 $cW[0] $cW[1] $cW[2]
ClearP 121 65
ClearP 122 65
ClearP 123 65
ClearP 124 65
Write-Host "fix3: new-cuff stray flecks cleaned"

[System.Runtime.InteropServices.Marshal]::Copy($px, 0, $bd.Scan0, $px.Length)
$dst.UnlockBits($bd)
$outPath = Join-Path $root "_pxv2_hero_handup6.png"
$dst.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)

$big = New-Object System.Drawing.Bitmap ($w*4),($h*4)
$gb = [System.Drawing.Graphics]::FromImage($big)
$gb.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$gb.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$bigRect = New-Object System.Drawing.Rectangle 0,0,($w*4),($h*4)
$gb.DrawImage($dst, $bigRect)
$gb.Dispose()
$bigPath = Join-Path $root "_pxv2_hero_handup6_big.png"
$big.Save($bigPath, [System.Drawing.Imaging.ImageFormat]::Png)
$big.Dispose(); $dst.Dispose()
Write-Host "done: _pxv2_hero_handup6.png + _big"

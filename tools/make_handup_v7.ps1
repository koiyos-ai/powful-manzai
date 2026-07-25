# make_handup_v7.ps1 - full rebuild from clean base per reference-image study.
# Root cause found: _pxv2_hero_nofist.png still contains the FULL original down-hanging
# SLEEVE (fist only was removed) - a diagonal fold-lined bulge sitting left of the true
# jacket side-seam, spanning roughly y109-158. Every prior version (v3-v6) painted a new
# sleeve on top of this but never erased it, so its outline/fold-lines/cuff-remnant kept
# showing through as "the original arm remains" (user-reported, 2026-07-14).
# Reference photo study (raised-arm illustration, same character):
#  - sleeve emerges close to the head/ear, arcs up with a SINGLE smooth taper, one soft
#    fold highlight - no scattered accents
#  - cuff = clean tilted white band, flush against the fist (no gap, no decoration)
#  - fist = plain circle, one outline, one highlight, no extra marks
#  - the gap between sleeve and torso is a smooth crescent, not a jagged notch
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$basePath = Join-Path $root "_pxv2_hero_nofist.png"

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

$cK   = @(8,8,8)
$cR1  = @(248,8,24)
$cRim = @(184,8,8)
$cE   = @(232,8,24)
$cWh  = @(248,248,248)
$cS   = @(248,200,168)
$cA   = @(232,152,120)
$cHi  = @(248,224,200)

# === STEP 1: erase the leftover original sleeve fill, up to the TRUE torso edge (~x149) ===
# (the sleeve's own leftmost outline bulges to x137 at its widest - erasing only up to that
#  point, as v7-draft1 did, left the sleeve's fill/fold-lines/cuff-remnant fully in place.
#  The real jacket edge sits further right, at a fairly flat x148-151 for the whole span -
#  confirmed directly against the nofist.png pixel data - so cut a flat line at x=148.)
for ($y=109; $y -le 161; $y++) {
  for ($x=100; $x -le 148; $x++) { ClearP $x $y }
}
Write-Host "step1: old sleeve fill erased (y109-161, x100-148)"

# === STEP 2: new sleeve tube - shoulder(149,108) -> wrist(117,80), single smooth taper ===
$sx0=149.0; $sy0=108.0; $hw0=10.0
$sx1=117.0; $sy1=80.0;  $hw1=8.0
$steps = 44
for ($i=0; $i -le $steps; $i++) {
  $t = $i / [double]$steps
  $cx = $sx0 + ($sx1-$sx0)*$t
  $cy = $sy0 + ($sy1-$sy0)*$t
  $hw = $hw0 + ($hw1-$hw0)*$t
  $ix = [int][math]::Round($cx); $iy = [int][math]::Round($cy)
  $ihw = [int][math]::Round($hw)
  $L = $ix - $ihw; $R = $ix + $ihw
  for ($yy=$iy; $yy -le $iy+1; $yy++) {
    SetP $L $yy $cK[0] $cK[1] $cK[2]
    SetP $R $yy $cK[0] $cK[1] $cK[2]
    SetP ($L+1) $yy $cRim[0] $cRim[1] $cRim[2]
    for ($ax = $L+2; $ax -le $R-1; $ax++) {
      SetP $ax $yy $cR1[0] $cR1[1] $cR1[2]
    }
  }
}
# single soft fold highlight, one clean diagonal streak at the natural bend (t=0.35-0.55)
for ($i=15; $i -le 24; $i++) {
  $t = $i/[double]$steps
  $cx = [int][math]::Round($sx0 + ($sx1-$sx0)*$t) + 1
  $cy = [int][math]::Round($sy0 + ($sy1-$sy0)*$t)
  SetP $cx $cy $cE[0] $cE[1] $cE[2]
}
Write-Host "step2: sleeve tube drawn"

# === STEP 3: cuff - clean tilted white band at the wrist end, flush (no gap) ===
$dirx = $sx1-$sx0; $diry=$sy1-$sy0
$len = [math]::Sqrt($dirx*$dirx+$diry*$diry)
$ux = $dirx/$len; $uy = $diry/$len
$nx = -$uy; $ny = $ux
$cuffCx = $sx1 + $ux*1.5; $cuffCy = $sy1 + $uy*1.5
for ($band=0; $band -le 2; $band++) {
  $bx = $cuffCx + $ux*$band
  $by = $cuffCy + $uy*$band
  $edgeCol = if ($band -eq 0 -or $band -eq 2) { $cK } else { $cWh }
  for ($p=-7; $p -le 7; $p++) {
    $px2 = [int][math]::Round($bx + $nx*$p)
    $py2 = [int][math]::Round($by + $ny*$p)
    if ([math]::Abs($p) -ge 7) { SetP $px2 $py2 $cK[0] $cK[1] $cK[2] }
    else { SetP $px2 $py2 $edgeCol[0] $edgeCol[1] $edgeCol[2] }
  }
}
Write-Host "step3: cuff drawn"

# === STEP 4: fist - plain circle, one outline, one highlight, flush against the cuff ===
$fistCx = $sx1 + $ux*8.5; $fistCy = $sy1 + $uy*8.5
$fr = 8.5
for ($fy = -9; $fy -le 9; $fy++) {
  for ($fx = -9; $fx -le 9; $fx++) {
    $dist = [math]::Sqrt($fx*$fx+$fy*$fy)
    if ($dist -gt $fr+0.5) { continue }
    $px2 = [int][math]::Round($fistCx+$fx); $py2 = [int][math]::Round($fistCy+$fy)
    if ($dist -gt $fr-0.8) { SetP $px2 $py2 $cK[0] $cK[1] $cK[2]; continue }
    # highlight: upper-left quadrant, small blob
    $hlDx = $fx - (-3); $hlDy = $fy - (-3)
    if (($hlDx*$hlDx + $hlDy*$hlDy) -lt 9) { SetP $px2 $py2 $cHi[0] $cHi[1] $cHi[2]; continue }
    # shade: lower-right quadrant darker
    if ($fx + $fy -gt 3) { SetP $px2 $py2 $cA[0] $cA[1] $cA[2]; continue }
    SetP $px2 $py2 $cS[0] $cS[1] $cS[2]
  }
}
Write-Host "step4: fist drawn"

[System.Runtime.InteropServices.Marshal]::Copy($px, 0, $bd.Scan0, $px.Length)
$dst.UnlockBits($bd)
$outPath = Join-Path $root "_pxv2_hero_handup7.png"
$dst.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)

$big = New-Object System.Drawing.Bitmap ($w*4),($h*4)
$gb = [System.Drawing.Graphics]::FromImage($big)
$gb.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$gb.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$bigRect = New-Object System.Drawing.Rectangle 0,0,($w*4),($h*4)
$gb.DrawImage($dst, $bigRect)
$gb.Dispose()
$bigPath = Join-Path $root "_pxv2_hero_handup7_big.png"
$big.Save($bigPath, [System.Drawing.Imaging.ImageFormat]::Png)
$big.Dispose(); $dst.Dispose()
Write-Host "done: _pxv2_hero_handup7.png + _big"

# make_handup_v8.ps1 - redraw with proportions traced/measured from the reference's own
# pixel-art conversion (_ref_pixelart.png, native 136x181, roughly same overall scale as
# our 352x192 canvas: 181 vs 192 tall). Measured directly off that file:
#   - fist: a clean circle, ~24px diameter at reference scale -> keep close to our own
#     existing down-hand fist size (own house style), NOT shrunk down like v5-v7 did
#   - sleeve: markedly SLIMMER than the fist (roughly half its diameter) - v7's tube was
#     nearly as wide as the fist, which reads wrong; slim it down
#   - sleeve hugs close to the head/ear at the shoulder, almost no background gap at top
#   - cuff: a clean tilted band flush against the fist, no gap, no decoration
# Reuses v7's step1 (old-sleeve erasure), which was confirmed correct.
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

# === STEP 1: erase the leftover original sleeve fill (same as v7, confirmed correct) ===
for ($y=109; $y -le 161; $y++) {
  for ($x=100; $x -le 148; $x++) { ClearP $x $y }
}
Write-Host "step1: old sleeve fill erased"

# === STEP 2: sleeve tube - SLIMMER than v7, shoulder hugs the ear closely ===
$sx0=149.0; $sy0=106.0; $hw0=6.0
$sx1=119.0; $sy1=79.0;  $hw1=5.0
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
# single soft fold highlight
for ($i=14; $i -le 22; $i++) {
  $t = $i/[double]$steps
  $cx = [int][math]::Round($sx0 + ($sx1-$sx0)*$t) + 1
  $cy = [int][math]::Round($sy0 + ($sy1-$sy0)*$t)
  SetP $cx $cy $cE[0] $cE[1] $cE[2]
}
Write-Host "step2: slim sleeve tube drawn"

# === STEP 3: cuff - clean tilted band, flush against the fist ===
$dirx = $sx1-$sx0; $diry=$sy1-$sy0
$len = [math]::Sqrt($dirx*$dirx+$diry*$diry)
$ux = $dirx/$len; $uy = $diry/$len
$nx = -$uy; $ny = $ux
$cuffCx = $sx1 + $ux*1.0; $cuffCy = $sy1 + $uy*1.0
for ($band=0; $band -le 2; $band++) {
  $bx = $cuffCx + $ux*$band
  $by = $cuffCy + $uy*$band
  $edgeCol = if ($band -eq 0 -or $band -eq 2) { $cK } else { $cWh }
  for ($p=-6; $p -le 6; $p++) {
    $px2 = [int][math]::Round($bx + $nx*$p)
    $py2 = [int][math]::Round($by + $ny*$p)
    if ([math]::Abs($p) -ge 6) { SetP $px2 $py2 $cK[0] $cK[1] $cK[2] }
    else { SetP $px2 $py2 $edgeCol[0] $edgeCol[1] $edgeCol[2] }
  }
}
Write-Host "step3: cuff drawn"

# === STEP 4: fist - big clean circle (radius 10, matching our own down-hand size), one highlight ===
$fistCx = $sx1 + $ux*10.5; $fistCy = $sy1 + $uy*10.5
$fr = 10.0
for ($fy = -11; $fy -le 11; $fy++) {
  for ($fx = -11; $fx -le 11; $fx++) {
    $dist = [math]::Sqrt($fx*$fx+$fy*$fy)
    if ($dist -gt $fr+0.5) { continue }
    $px2 = [int][math]::Round($fistCx+$fx); $py2 = [int][math]::Round($fistCy+$fy)
    if ($dist -gt $fr-0.9) { SetP $px2 $py2 $cK[0] $cK[1] $cK[2]; continue }
    $hlDx = $fx - (-3.5); $hlDy = $fy - (-3.5)
    if (($hlDx*$hlDx + $hlDy*$hlDy) -lt 11) { SetP $px2 $py2 $cHi[0] $cHi[1] $cHi[2]; continue }
    if ($fx + $fy -gt 4) { SetP $px2 $py2 $cA[0] $cA[1] $cA[2]; continue }
    SetP $px2 $py2 $cS[0] $cS[1] $cS[2]
  }
}
Write-Host "step4: fist drawn"

[System.Runtime.InteropServices.Marshal]::Copy($px, 0, $bd.Scan0, $px.Length)
$dst.UnlockBits($bd)
$outPath = Join-Path $root "_pxv2_hero_handup8.png"
$dst.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)

$big = New-Object System.Drawing.Bitmap ($w*4),($h*4)
$gb = [System.Drawing.Graphics]::FromImage($big)
$gb.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$gb.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$bigRect = New-Object System.Drawing.Rectangle 0,0,($w*4),($h*4)
$gb.DrawImage($dst, $bigRect)
$gb.Dispose()
$bigPath = Join-Path $root "_pxv2_hero_handup8_big.png"
$big.Save($bigPath, [System.Drawing.Imaging.ImageFormat]::Png)
$big.Dispose(); $dst.Dispose()
Write-Host "done: _pxv2_hero_handup8.png + _big"

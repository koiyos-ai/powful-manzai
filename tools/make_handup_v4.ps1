# make_handup_v4.ps1 - Rebuild raised-arm pose using real reference proportions
# Sleeve length/width/shading matched to the actual down-arm sleeve (measured, not invented).
# Fist is the REAL fist pixels copied (not redrawn), so shape/highlight stay authentic.
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$basePath = Join-Path $root "_pxv2_hero_nofist.png"   # fist already erased+patched here
$refPath  = Join-Path $root "_pxv2_hero_base.png"     # untouched, source of real fist pixels
if (-not (Test-Path $basePath)) { Write-Error "base not found: $basePath"; exit 1 }

$srcImg = [System.Drawing.Bitmap]::FromFile($basePath)
$w = $srcImg.Width; $h = $srcImg.Height
$dst = New-Object System.Drawing.Bitmap $w,$h,([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$gfx = [System.Drawing.Graphics]::FromImage($dst)
$gfx.DrawImage($srcImg, 0, 0, $w, $h)
$gfx.Dispose(); $srcImg.Dispose()

$refImg = [System.Drawing.Bitmap]::FromFile($refPath)
$rw = $refImg.Width; $rh = $refImg.Height
$refRect = New-Object System.Drawing.Rectangle 0,0,$rw,$rh
$rbd = $refImg.LockBits($refRect,[System.Drawing.Imaging.ImageLockMode]::ReadOnly,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$rpx = New-Object byte[] ($rbd.Stride*$rh)
[System.Runtime.InteropServices.Marshal]::Copy($rbd.Scan0,$rpx,0,$rpx.Length)
$rst = $rbd.Stride
$refImg.UnlockBits($rbd)
function RefPx([int]$xx,[int]$yy){
  if($xx -lt 0 -or $xx -ge $rw -or $yy -lt 0 -or $yy -ge $rh){return @(0,0,0,0)}
  $o=$yy*$rst+$xx*4
  return @([int]$rpx[$o+2],[int]$rpx[$o+1],[int]$rpx[$o],[int]$rpx[$o+3])
}

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
function ClrP([int]$xx,[int]$yy) {
  if ($xx -lt 0 -or $xx -ge $w -or $yy -lt 0 -or $yy -ge $h) { return }
  $o=$yy*$st+$xx*4; $px[$o]=0;$px[$o+1]=0;$px[$o+2]=0;$px[$o+3]=0
}
function ReadPx([int]$xx,[int]$yy) {
  if ($xx -lt 0 -or $xx -ge $w -or $yy -lt 0 -or $yy -ge $h) { return @(0,0,0,0) }
  $o=$yy*$st+$xx*4
  return @([int]$px[$o+2],[int]$px[$o+1],[int]$px[$o],[int]$px[$o+3])
}

$cK  = @(8,8,8)
$cR1 = @(248,8,24)
$cRim = @(184,8,8)
$cE  = @(232,8,24)
$cWh = @(248,248,248)

# === STEP 1: erase old sleeve wedge (shoulder y=106 to old-cuff y=134), x 130-160 ===
# measured left silhouette edge goes 152(y106) -> 137(y134); right side patched with plain jacket red
for ($ey=104; $ey -le 135; $ey++) {
  for ($ex=128; $ex -le 165; $ex++) {
    $c = ReadPx $ex $ey
    if ($c[3] -lt 128) { continue }
    $cr=$c[0]; $cg=$c[1]; $cb=$c[2]
    # red/rim/near-black sleeve tones (not skin, not the tie-yellow, not shirt-white/blue)
    if ($cr -gt 120 -and $cg -lt 60 -and $cb -lt 70) { ClrP $ex $ey; continue }
    if ($cr -lt 60 -and $cg -lt 60 -and $cb -lt 60) { ClrP $ex $ey; continue }
  }
}
# patch: fill cleared holes with flat jacket red + 1px black re-outline on the new torso edge
for ($ey=104; $ey -le 135; $ey++) {
  for ($ex=128; $ex -le 165; $ex++) {
    $c = ReadPx $ex $ey
    if ($c[3] -ge 128) { continue }
    # only fill if it has an opaque (torso) neighbor to the right, i.e. it was truly interior
    $rightNb = ReadPx ($ex+3) $ey
    if ($rightNb[3] -ge 128) { SetP $ex $ey $cR1[0] $cR1[1] $cR1[2] }
  }
}
Write-Host "step1: old sleeve wedge cleared+patched"

# === STEP 2: draw new raised sleeve tube (shoulder -> mirrored cuff position) ===
# shoulder attach (measured): (152,106) half-width 13 (puff)
# cuff attach (mirrored fist bbox top, (141,77)) half-width 9
$sx0=152.0; $sy0=106.0; $hw0=13.0
$sx1=141.0; $sy1=79.0;  $hw1=9.0
$steps = 60
for ($i=0; $i -le $steps; $i++) {
  $t = $i / [double]$steps
  $cx = $sx0 + ($sx1-$sx0)*$t
  $cy = $sy0 + ($sy1-$sy0)*$t
  $hw = $hw0 + ($hw1-$hw0)*$t
  $ix = [int][math]::Round($cx); $iy = [int][math]::Round($cy)
  $ihw = [int][math]::Round($hw)
  $L = $ix - $ihw; $R = $ix + $ihw
  SetP $L $iy $cK[0] $cK[1] $cK[2]
  SetP $R $iy $cK[0] $cK[1] $cK[2]
  SetP ($L+1) $iy $cRim[0] $cRim[1] $cRim[2]
  SetP ($R-1) $iy $cRim[0] $cRim[1] $cRim[2]
  for ($ax = $L+2; $ax -le $R-2; $ax++) {
    SetP $ax $iy $cR1[0] $cR1[1] $cR1[2]
  }
}
# two subtle fold-crease strokes (not periodic dither) along the tube, echoing reference style
for ($i=10; $i -le 16; $i++) {
  $t = $i/[double]$steps
  $cx = [int][math]::Round($sx0 + ($sx1-$sx0)*$t)
  $cy = [int][math]::Round($sy0 + ($sy1-$sy0)*$t)
  SetP ($cx-2) $cy $cE[0] $cE[1] $cE[2]
}
for ($i=32; $i -le 40; $i++) {
  $t = $i/[double]$steps
  $cx = [int][math]::Round($sx0 + ($sx1-$sx0)*$t)
  $cy = [int][math]::Round($sy0 + ($sy1-$sy0)*$t)
  SetP ($cx+2) $cy $cE[0] $cE[1] $cE[2]
}
Write-Host "step2: sleeve tube drawn"

# === STEP 3: cuff band, perpendicular to tube direction, just before the fist ===
$dirx = $sx1-$sx0; $diry=$sy1-$sy0
$len = [math]::Sqrt($dirx*$dirx+$diry*$diry)
$nx = -$diry/$len; $ny = $dirx/$len   # perpendicular unit vector
$cuffCx = $sx1; $cuffCy = $sy1 + 2   # just above fist top (fist bbox now starts at y=56, cuff sits at ~77-79)
for ($band=0; $band -le 1; $band++) {
  $bx = $cuffCx + $dirx/$len*$band
  $by = $cuffCy + $diry/$len*$band
  for ($p=-9; $p -le 9; $p++) {
    $px2 = [int][math]::Round($bx + $nx*$p)
    $py2 = [int][math]::Round($by + $ny*$p)
    if ([math]::Abs($p) -ge 9) { SetP $px2 $py2 $cK[0] $cK[1] $cK[2] }
    else { SetP $px2 $py2 $cWh[0] $cWh[1] $cWh[2] }
  }
}
Write-Host "step3: cuff drawn"

# === STEP 4: copy the REAL fist pixels (from untouched reference) to new position ===
# original fist bbox (measured): x=131..151, y=134..157 (pad 1px around 132-150/135-156)
# new position: same x, y shifted by (212-2*106)= same mirror axis: newY = 212 - oldY
$axis = 212
for ($fy=134; $fy -le 157; $fy++) {
  for ($fx=131; $fx -le 151; $fx++) {
    $c = RefPx $fx $fy
    if ($c[3] -lt 20) { continue }
    $ny2 = $axis - $fy
    SetP $fx $ny2 $c[0] $c[1] $c[2]
  }
}
Write-Host "step4: fist copied to new position"

# === SAVE ===
[System.Runtime.InteropServices.Marshal]::Copy($px, 0, $bd.Scan0, $px.Length)
$dst.UnlockBits($bd)
$outPath = Join-Path $root "_pxv2_hero_handup4.png"
$dst.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)

$big = New-Object System.Drawing.Bitmap ($w*4),($h*4)
$gb = [System.Drawing.Graphics]::FromImage($big)
$gb.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$gb.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$bigRect = New-Object System.Drawing.Rectangle 0,0,($w*4),($h*4)
$gb.DrawImage($dst, $bigRect)
$gb.Dispose()
$bigPath = Join-Path $root "_pxv2_hero_handup4_big.png"
$big.Save($bigPath, [System.Drawing.Imaging.ImageFormat]::Png)
$big.Dispose(); $dst.Dispose()
Write-Host "done: _pxv2_hero_handup4.png + _big"

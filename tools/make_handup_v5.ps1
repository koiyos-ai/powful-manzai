# make_handup_v5.ps1 - raised arm, corrected: fist clears the face, sleeve patch is solid (no artifacts)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$basePath = Join-Path $root "_pxv2_hero_nofist.png"
$refPath  = Join-Path $root "_pxv2_hero_base.png"

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

# === STEP 1: flatten old sleeve+shoulder-puff wedge to solid jacket red (measured RED zone: y107-133) ===
# any pixel that is red/rim/near-black outline within this box becomes flat R1; skin/other left untouched
for ($ey=103; $ey -le 136; $ey++) {
  for ($ex=128; $ex -le 158; $ex++) {
    $c = ReadPx $ex $ey
    if ($c[3] -lt 20) { continue }
    $cr=$c[0]; $cg=$c[1]; $cb=$c[2]
    $isSkin = ($cr -gt 200 -and $cg -gt 130 -and $cb -gt 90 -and $cg -gt $cb)
    $isWhite = ($cr -gt 220 -and $cg -gt 220 -and $cb -gt 220)
    if ($isSkin -or $isWhite) { continue }
    SetP $ex $ey $cR1[0] $cR1[1] $cR1[2]
  }
}
Write-Host "step1: old sleeve area flattened to solid red"

# === STEP 2: new raised sleeve tube, shoulder(150,109) -> cuff-end(115,77), clears the face/hair ===
$sx0=150.0; $sy0=109.0; $hw0=11.0
$sx1=116.0; $sy1=79.0;  $hw1=9.0
$steps = 48
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
    SetP ($R-1) $yy $cRim[0] $cRim[1] $cRim[2]
    for ($ax = $L+2; $ax -le $R-2; $ax++) {
      SetP $ax $yy $cR1[0] $cR1[1] $cR1[2]
    }
  }
}
# fold-crease accents (sparse, echoing the reference's diagonal creases - not periodic dither)
for ($i=8; $i -le 14; $i++) {
  $t = $i/[double]$steps
  $cx = [int][math]::Round($sx0 + ($sx1-$sx0)*$t) - 2
  $cy = [int][math]::Round($sy0 + ($sy1-$sy0)*$t)
  SetP $cx $cy $cE[0] $cE[1] $cE[2]
}
for ($i=26; $i -le 32; $i++) {
  $t = $i/[double]$steps
  $cx = [int][math]::Round($sx0 + ($sx1-$sx0)*$t) + 2
  $cy = [int][math]::Round($sy0 + ($sy1-$sy0)*$t)
  SetP $cx $cy $cE[0] $cE[1] $cE[2]
}
Write-Host "step2: sleeve tube drawn"

# === STEP 3: cuff band perpendicular to tube direction, at the wrist end ===
$dirx = $sx1-$sx0; $diry=$sy1-$sy0
$len = [math]::Sqrt($dirx*$dirx+$diry*$diry)
$ux = $dirx/$len; $uy = $diry/$len
$nx = -$uy; $ny = $ux
$cuffCx = $sx1 + $ux*3; $cuffCy = $sy1 + $uy*3
for ($band=0; $band -le 1; $band++) {
  $bx = $cuffCx + $ux*$band
  $by = $cuffCy + $uy*$band
  for ($p=-8; $p -le 8; $p++) {
    $px2 = [int][math]::Round($bx + $nx*$p)
    $py2 = [int][math]::Round($by + $ny*$p)
    if ([math]::Abs($p) -ge 8) { SetP $px2 $py2 $cK[0] $cK[1] $cK[2] }
    else { SetP $px2 $py2 $cWh[0] $cWh[1] $cWh[2] }
  }
}
Write-Host "step3: cuff drawn"

# === STEP 4: copy the REAL fist pixels to the new position (no flip -> highlight stays upper-left) ===
# original fist bbox: x=131..151, y=134..157 ; original center approx (141,145.5)
$origCx = 141.0; $origCy = 145.5
$newCx = $sx1; $newCy = $sy1 - 8   # fist center just beyond the cuff
$dx = [int][math]::Round($newCx - $origCx)
$dy = [int][math]::Round($newCy - $origCy)
for ($fy=134; $fy -le 157; $fy++) {
  for ($fx=131; $fx -le 151; $fx++) {
    $c = RefPx $fx $fy
    if ($c[3] -lt 20) { continue }
    SetP ($fx+$dx) ($fy+$dy) $c[0] $c[1] $c[2]
  }
}
Write-Host "step4: fist copied to new position ($newCx,$newCy)"

[System.Runtime.InteropServices.Marshal]::Copy($px, 0, $bd.Scan0, $px.Length)
$dst.UnlockBits($bd)
$outPath = Join-Path $root "_pxv2_hero_handup5.png"
$dst.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)

$big = New-Object System.Drawing.Bitmap ($w*4),($h*4)
$gb = [System.Drawing.Graphics]::FromImage($big)
$gb.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$gb.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$bigRect = New-Object System.Drawing.Rectangle 0,0,($w*4),($h*4)
$gb.DrawImage($dst, $bigRect)
$gb.Dispose()
$bigPath = Join-Path $root "_pxv2_hero_handup5_big.png"
$big.Save($bigPath, [System.Drawing.Imaging.ImageFormat]::Png)
$big.Dispose(); $dst.Dispose()
Write-Host "done: _pxv2_hero_handup5.png + _big"

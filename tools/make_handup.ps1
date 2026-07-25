# make_handup.ps1 - Create hand-raise pose variant from base dot-art
# v3: fist matches original size, seamless sleeve-fist connection
# ASCII only / Windows PowerShell 5.1 compatible
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$basePath = Join-Path $root "_pxv2_hero_base.png"
if (-not (Test-Path $basePath)) { Write-Error "base not found: $basePath"; exit 1 }

$srcImg = [System.Drawing.Bitmap]::FromFile($basePath)
$w = $srcImg.Width; $h = $srcImg.Height
$dst = New-Object System.Drawing.Bitmap $w,$h,([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$gfx = [System.Drawing.Graphics]::FromImage($dst)
$gfx.DrawImage($srcImg, 0, 0, $w, $h)
$gfx.Dispose(); $srcImg.Dispose()

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

# Palette
$cK  = @(8,8,8)
$cR1 = @(248,8,24)
$cR2 = @(232,8,24)
$cRd = @(184,8,8)
$cS1 = @(248,200,168)
$cSs = @(232,152,120)
$cWh = @(248,248,248)

# === STEP 1: Erase left fist ===
for ($ey=134; $ey -le 158; $ey++) {
  for ($ex=130; $ex -le 151; $ex++) {
    $c = ReadPx $ex $ey
    if ($c[3] -lt 128) { continue }
    $cr=$c[0]; $cg=$c[1]; $cb=$c[2]
    if ($cr -gt 170 -and $cg -gt 120 -and $cb -gt 80 -and $cr -gt $cg) { ClrP $ex $ey; continue }
    if ($cr -gt 220 -and $cg -gt 220 -and $cb -gt 220) { ClrP $ex $ey; continue }
    if ($cr -lt 60 -and $cg -lt 60 -and $cb -lt 60 -and $ex -lt 148) { ClrP $ex $ey; continue }
    if ($cr -gt 200 -and $cg -gt 100 -and $cg -lt 170 -and $cb -gt 60 -and $cb -lt 140 -and $cr -gt $cg) { ClrP $ex $ey; continue }
  }
}
Write-Host "step1: fist erased"

# === STEP 2: Patch jacket left edge ===
for ($ey=134; $ey -le 157; $ey++) {
  $edgeX = 137 + [int][math]::Floor(($ey - 134) * 3.0 / 24.0)
  SetP $edgeX $ey $cK[0] $cK[1] $cK[2]
  SetP ($edgeX+1) $ey $cK[0] $cK[1] $cK[2]
  for ($ex = $edgeX+2; $ex -le 149; $ex++) {
    $c = ReadPx $ex $ey
    if ($c[3] -lt 128) {
      if (($ex + $ey) % 7 -eq 0) { SetP $ex $ey $cRd[0] $cRd[1] $cRd[2] }
      else { SetP $ex $ey $cR1[0] $cR1[1] $cR1[2] }
    }
  }
}
Write-Host "step2: jacket patched"

# === STEP 3: Draw raised arm sleeve (y=30..80) ===
# Center path: (112, 30) to (127, 80)
# Width: total 14px at wrist, 16px at shoulder
for ($ay=30; $ay -le 80; $ay++) {
  $t = ($ay - 30) / 50.0  # 0=wrist, 1=shoulder
  $cx = [int][math]::Round(112 + $t * 15)
  $hw = [int][math]::Round(6.0 + $t * 1.5)  # 6 at wrist, 7-8 at shoulder
  # Outlines
  SetP ($cx - $hw - 1) $ay $cK[0] $cK[1] $cK[2]
  SetP ($cx + $hw + 1) $ay $cK[0] $cK[1] $cK[2]
  # Shadow edges (2px on each side for volume)
  SetP ($cx - $hw) $ay $cRd[0] $cRd[1] $cRd[2]
  SetP ($cx - $hw + 1) $ay $cRd[0] $cRd[1] $cRd[2]
  SetP ($cx + $hw) $ay $cRd[0] $cRd[1] $cRd[2]
  # Main red fill
  for ($ax = ($cx - $hw + 2); $ax -le ($cx + $hw - 1); $ax++) {
    if (($ax + $ay) % 11 -eq 0) { SetP $ax $ay $cR2[0] $cR2[1] $cR2[2] }
    else { SetP $ax $ay $cR1[0] $cR1[1] $cR1[2] }
  }
}
Write-Host "step3: arm sleeve drawn"

# === STEP 4: Draw fist (center 112,16, same scale as original ~18x22) ===
# Original fist: x=132..150 y=136..158 = 18x22 px
# Raised fist: rx=9 ry=11 -> 18x22
$fCX = 112; $fCY = 16; $fRX = 9.0; $fRY = 11.0
for ($fy = [int]($fCY-$fRY-2); $fy -le [int]($fCY+$fRY+2); $fy++) {
  for ($fx = [int]($fCX-$fRX-2); $fx -le [int]($fCX+$fRX+2); $fx++) {
    $ddx = ($fx - $fCX) / $fRX
    $ddy = ($fy - $fCY) / $fRY
    $dist = [math]::Sqrt($ddx*$ddx + $ddy*$ddy)
    if ($dist -le 0.6) {
      SetP $fx $fy $cS1[0] $cS1[1] $cS1[2]
    } elseif ($dist -le 0.82) {
      if ($fx -gt $fCX -or $fy -gt $fCY) { SetP $fx $fy $cSs[0] $cSs[1] $cSs[2] }
      else { SetP $fx $fy $cS1[0] $cS1[1] $cS1[2] }
    } elseif ($dist -le 1.08) {
      SetP $fx $fy $cK[0] $cK[1] $cK[2]
    }
  }
}
# Highlight (upper-left, matching original fist pattern: 4x3 white block)
for ($hy = ($fCY-5); $hy -le ($fCY-2); $hy++) {
  for ($hx = ($fCX-5); $hx -le ($fCX-2); $hx++) {
    $ddx = ($hx - $fCX) / $fRX; $ddy = ($hy - $fCY) / $fRY
    $dist = [math]::Sqrt($ddx*$ddx + $ddy*$ddy)
    if ($dist -lt 0.82) { SetP $hx $hy $cWh[0] $cWh[1] $cWh[2] }
  }
}
Write-Host "step4: fist drawn"

# === STEP 5: Wrist cuff (white line between fist and sleeve) ===
# At y=28-29 (just below fist bottom, just above arm top)
for ($cy=28; $cy -le 29; $cy++) {
  $wCx = 112; $wHw = 6
  SetP ($wCx - $wHw - 1) $cy $cK[0] $cK[1] $cK[2]
  SetP ($wCx + $wHw + 1) $cy $cK[0] $cK[1] $cK[2]
  for ($cx2 = ($wCx - $wHw); $cx2 -le ($wCx + $wHw); $cx2++) {
    SetP $cx2 $cy $cWh[0] $cWh[1] $cWh[2]
  }
}
Write-Host "step5: cuff drawn"

# === STEP 6: Shoulder transition ===
for ($ay=72; $ay -le 82; $ay++) {
  $t = ($ay - 30) / 50.0
  $cx = [int][math]::Round(112 + $t * 15)
  $hw = [int][math]::Round(6.0 + $t * 1.5)
  $rx = $cx + $hw + 1
  $rightPx = ReadPx ($rx+1) $ay
  if ($rightPx[3] -gt 128) {
    SetP $rx $ay $cR1[0] $cR1[1] $cR1[2]
  }
}
# Fill gaps between arm and body at shoulder level
for ($ay=74; $ay -le 82; $ay++) {
  $t = ($ay - 30) / 50.0
  $cx = [int][math]::Round(112 + $t * 15)
  $hw = [int][math]::Round(6.0 + $t * 1.5)
  $armRight = $cx + $hw + 1
  for ($sx = $armRight + 1; $sx -le $armRight + 6; $sx++) {
    $sp = ReadPx $sx $ay
    if ($sp[3] -gt 128) { break }
    SetP $sx $ay $cR1[0] $cR1[1] $cR1[2]
  }
}
Write-Host "step6: shoulder blended"

# === SAVE ===
[System.Runtime.InteropServices.Marshal]::Copy($px, 0, $bd.Scan0, $px.Length)
$dst.UnlockBits($bd)
$outPath = Join-Path $root "_pxv2_hero_handup.png"
$dst.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)

$big = New-Object System.Drawing.Bitmap ($w*4),($h*4)
$gb = [System.Drawing.Graphics]::FromImage($big)
$gb.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$gb.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$gb.DrawImage($dst, (New-Object System.Drawing.Rectangle 0,0,($w*4),($h*4)))
$gb.Dispose()
$bigPath = Join-Path $root "_pxv2_hero_handup_big.png"
$big.Save($bigPath, [System.Drawing.Imaging.ImageFormat]::Png)
$big.Dispose(); $dst.Dispose()
Write-Host "done: _pxv2_hero_handup.png + _big"

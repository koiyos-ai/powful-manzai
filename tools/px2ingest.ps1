# px2ingest.ps1 - Dot-art engine v2: ingest a smooth flat-color illustration into a true dot-art draft.
# Usage: powershell -ExecutionPolicy Bypass -File tools\px2ingest.ps1 -src images\hero.png -out _pxv2_hero_base.png -scale 4 -colors 26
# Core idea: MODE (majority-color) downscale per block, NOT averaging - flat illustrations keep
# pure colors (a yellow tie stays yellow instead of blending into the red jacket).
# Steps: 1) mode-downscale by -scale (posterized 16-step bins, alpha majority)
#        2) palette: hue-sector coverage first, then frequency, cap at -colors
#        3) map pixels to nearest palette color  4) drop isolated pixels  5) save 1x and 4x previews.
# ASCII only / Windows PowerShell 5.1 compatible. Uses LockBits for speed.
# NOTE: PowerShell variable names are CASE-INSENSITIVE - never use $w/$W as different vars.
param(
  [string]$src = "images\hero.png",
  [string]$out = "_pxv2_hero_base.png",
  [int]$scale = 4,
  [int]$colors = 26
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root $src))) { $root = (Get-Location).Path }
$srcPath = Join-Path $root $src
$outPath = Join-Path $root $out

# --- load source into byte array (BGRA) ---
$img0 = [System.Drawing.Bitmap]::FromFile($srcPath)
$img = New-Object System.Drawing.Bitmap $img0.Width, $img0.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g0 = [System.Drawing.Graphics]::FromImage($img); $g0.DrawImage($img0, 0, 0, $img0.Width, $img0.Height); $g0.Dispose(); $img0.Dispose()
$srcW = $img.Width; $srcH = $img.Height
$rect = New-Object System.Drawing.Rectangle 0,0,$srcW,$srcH
$bd = $img.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$srcBytes = New-Object byte[] ($bd.Stride * $srcH)
[System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $srcBytes, 0, $srcBytes.Length)
$stride = $bd.Stride
$img.UnlockBits($bd); $img.Dispose()

$dstW = [int][math]::Floor($srcW / $scale)
$dstH = [int][math]::Floor($srcH / $scale)

# --- 1) mode-downscale: majority posterized color per block (16-step bins) ---
$dw = New-Object int[] ($dstW*$dstH)   # packed RGB (-1 = transparent)
for ($y=0; $y -lt $dstH; $y++) {
  for ($x=0; $x -lt $dstW; $x++) {
    $cnt = @{}; $opaque = 0; $total = 0
    for ($by=0; $by -lt $scale; $by++) {
      $sy = $y*$scale+$by; if ($sy -ge $srcH) { continue }
      $rowOff = $sy*$stride
      for ($bx=0; $bx -lt $scale; $bx++) {
        $sx = $x*$scale+$bx; if ($sx -ge $srcW) { continue }
        $o = $rowOff + $sx*4
        $a = $srcBytes[$o+3]; $total++
        if ($a -lt 128) { continue }
        $opaque++
        $r = [int][math]::Floor($srcBytes[$o+2]/16)*16+8
        $gch = [int][math]::Floor($srcBytes[$o+1]/16)*16+8
        $b = [int][math]::Floor($srcBytes[$o]  /16)*16+8
        $key = ($r -shl 16) -bor ($gch -shl 8) -bor $b
        if ($cnt.ContainsKey($key)) { $cnt[$key] = $cnt[$key]+1 } else { $cnt[$key] = 1 }
      }
    }
    if ($opaque*2 -lt $total -or $total -eq 0) { $dw[$y*$dstW+$x] = -1; continue }
    $bestK = -1; $bestC = -1
    foreach ($e in $cnt.GetEnumerator()) {
      if ($e.Value -gt $bestC) { $bestC = $e.Value; $bestK = $e.Key }
      elseif ($e.Value -eq $bestC -and $e.Key -lt $bestK) { $bestK = $e.Key } # tie: darker wins (keeps outlines)
    }
    $dw[$y*$dstW+$x] = $bestK
  }
}
$nOpq=0; foreach($v in $dw){ if($v -ge 0){$nOpq++} }
Write-Host ("downscaled opaque px = {0} / {1}" -f $nOpq, $dw.Length)

# --- 2) palette: hue-sector coverage first, then frequency ---
$hist = @{}
foreach ($v in $dw) { if ($v -lt 0) { continue }
  if ($hist.ContainsKey($v)) { $hist[$v] = $hist[$v]+1 } else { $hist[$v] = 1 } }
function HueSector([int]$r,[int]$g,[int]$b){
  $mx=[math]::Max($r,[math]::Max($g,$b)); $mn=[math]::Min($r,[math]::Min($g,$b))
  if (($mx-$mn) -lt 24) { if ($mx -gt 200) { return "NW" } elseif ($mx -lt 72) { return "NK" } else { return "NG" } }
  $hue=0.0
  if ($mx -eq $r) { $hue = 60.0*(($g-$b)/($mx-$mn)) }
  elseif ($mx -eq $g) { $hue = 60.0*(2+($b-$r)/($mx-$mn)) }
  else { $hue = 60.0*(4+($r-$g)/($mx-$mn)) }
  if ($hue -lt 0) { $hue += 360 }
  return [string][int][math]::Floor($hue/30)
}
# Materialize bins into plain arrays sorted by count desc (avoids PS pipeline/Sort-Object traps)
$binK = New-Object int[] $hist.Count
$binV = New-Object int[] $hist.Count
$bi = 0
foreach ($k in $hist.Keys) { $binK[$bi] = [int]$k; $binV[$bi] = [int]$hist[$k]; $bi++ }
[array]::Sort($binV, $binK)          # ascending sort by count, binK follows
[array]::Reverse($binK); [array]::Reverse($binV)  # to descending
Write-Host ("hist.Count={0} bins={1}" -f $hist.Count, $binK.Length)
if ($env:PX2_DEBUG -eq "1") {
  Write-Host "--- top 40 bins ---"
  $n40 = [math]::Min(40, $binK.Length)
  for ($i=0; $i -lt $n40; $i++) {
    $r=($binK[$i] -shr 16) -band 255; $gch=($binK[$i] -shr 8) -band 255; $b=$binK[$i] -band 255
    $sec = HueSector $r $gch $b
    $mx=[math]::Max($r,[math]::Max($gch,$b)); $mn=[math]::Min($r,[math]::Min($gch,$b))
    $band="P"; if ($mx -gt 0 -and (($mx-$mn)/$mx) -ge 0.45) { $band="V" }
    Write-Host ("  {0,5}  rgb({1},{2},{3})  {4}|{5}" -f $binV[$i],$r,$gch,$b,$sec,$band)
  }
}
$sel = New-Object System.Collections.ArrayList
$seenSector = @{}
for ($i=0; $i -lt $binK.Length; $i++) {
  # Reserve the top bin of each (hue sector x saturation band) first, so that
  # vivid small-area colors (yellow tie) are not crowded out by pale large-area colors (skin).
  $r=($binK[$i] -shr 16) -band 255; $gch=($binK[$i] -shr 8) -band 255; $b=$binK[$i] -band 255
  $sec = HueSector $r $gch $b
  $mx=[math]::Max($r,[math]::Max($gch,$b)); $mn=[math]::Min($r,[math]::Min($gch,$b))
  $band = "P"; if ($mx -gt 0 -and (($mx-$mn)/$mx) -ge 0.45) { $band = "V" }
  $skey = "$sec|$band"
  if ($i -lt 6) { Write-Host ("p1[{0}]: key={1} rgb({2},{3},{4}) mx={5} mn={6} sec={7} band={8}" -f $i,$binK[$i],$r,$gch,$b,$mx,$mn,$sec,$band) }
  if (-not $seenSector.ContainsKey($skey)) { $seenSector[$skey]=1; [void]$sel.Add($binK[$i]) }
}
Write-Host ("pass1: sel={0} sectors=[{1}]" -f $sel.Count, (@($seenSector.Keys) -join ","))
for ($i=0; $i -lt $binK.Length; $i++) {
  if ($sel.Count -ge $colors) { break }
  if (-not $sel.Contains($binK[$i])) { [void]$sel.Add($binK[$i]) }
}
$palR = New-Object int[] $sel.Count; $palG = New-Object int[] $sel.Count; $palB = New-Object int[] $sel.Count
for ($i=0; $i -lt $sel.Count; $i++) { $palR[$i]=($sel[$i] -shr 16) -band 255; $palG[$i]=($sel[$i] -shr 8) -band 255; $palB[$i]=$sel[$i] -band 255 }
Write-Host ("palette ({0} colors):" -f $sel.Count)
for ($i=0; $i -lt $sel.Count; $i++) { Write-Host ("  rgb({0},{1},{2})" -f $palR[$i],$palG[$i],$palB[$i]) }

# --- 3) map to nearest palette color ---
for ($i=0; $i -lt $dw.Length; $i++) {
  $v = $dw[$i]; if ($v -lt 0) { continue }
  $r=($v -shr 16) -band 255; $gch=($v -shr 8) -band 255; $b=$v -band 255
  $bestJ=0; $bestD=[int]::MaxValue
  for ($j=0; $j -lt $sel.Count; $j++) {
    $dr=$r-$palR[$j]; $dg=$gch-$palG[$j]; $db=$b-$palB[$j]
    $d=$dr*$dr+$dg*$dg+$db*$db
    if ($d -lt $bestD) { $bestD=$d; $bestJ=$j }
  }
  $dw[$i] = ($palR[$bestJ] -shl 16) -bor ($palG[$bestJ] -shl 8) -bor $palB[$bestJ]
}

# --- 4) drop isolated opaque pixels (fewer than 2 opaque 8-neighbors) ---
$removed = 0
for ($y=0; $y -lt $dstH; $y++) {
  for ($x=0; $x -lt $dstW; $x++) {
    if ($dw[$y*$dstW+$x] -lt 0) { continue }
    $n=0
    for ($dy=-1; $dy -le 1; $dy++) { for ($dx=-1; $dx -le 1; $dx++) {
      if ($dx -eq 0 -and $dy -eq 0) { continue }
      $nx=$x+$dx; $ny=$y+$dy
      if ($nx -lt 0 -or $ny -lt 0 -or $nx -ge $dstW -or $ny -ge $dstH) { continue }
      if ($dw[$ny*$dstW+$nx] -ge 0) { $n++ }
    } }
    if ($n -lt 2) { $dw[$y*$dstW+$x] = -1; $removed++ }
  }
}
Write-Host ("cleanup: removed {0} isolated pixels" -f $removed)

# --- 5) write output + x4 preview ---
$dst = New-Object System.Drawing.Bitmap $dstW, $dstH, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$bdOut = $dst.LockBits((New-Object System.Drawing.Rectangle 0,0,$dstW,$dstH), [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$outBytes = New-Object byte[] ($bdOut.Stride * $dstH)
for ($y=0; $y -lt $dstH; $y++) {
  for ($x=0; $x -lt $dstW; $x++) {
    $v = $dw[$y*$dstW+$x]; $o = $y*$bdOut.Stride + $x*4
    if ($v -lt 0) { continue }
    $outBytes[$o]   = $v -band 255
    $outBytes[$o+1] = ($v -shr 8) -band 255
    $outBytes[$o+2] = ($v -shr 16) -band 255
    $outBytes[$o+3] = 255
  }
}
[System.Runtime.InteropServices.Marshal]::Copy($outBytes, 0, $bdOut.Scan0, $outBytes.Length)
$dst.UnlockBits($bdOut)
$dst.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)

$big = New-Object System.Drawing.Bitmap ($dstW*4), ($dstH*4)
$g2 = [System.Drawing.Graphics]::FromImage($big)
$g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g2.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$g2.DrawImage($dst, (New-Object System.Drawing.Rectangle 0,0,($dstW*4),($dstH*4)))
$g2.Dispose()
$bigPath = $outPath -replace "\.png$", "_big.png"
$big.Save($bigPath, [System.Drawing.Imaging.ImageFormat]::Png)
$big.Dispose(); $dst.Dispose()
Write-Host ("wrote {0} ({1}x{2}) and {3} (x4 preview)" -f $out,$dstW,$dstH,(Split-Path -Leaf $bigPath))

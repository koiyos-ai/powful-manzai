# Make an eyes+brows expression part from a fal.ai output, aligned to images/parts/yada_master.png,
# then composite over images/parts/yada_noeyes.png for preview.
# Output: images/parts/yada_eyes_<expr>.png + _expr_<expr>.png (preview, untracked)
# usage: powershell -File tools\make_expression.ps1 <falImage.png> <expr>
# Run from the repo root (paths below are relative to it).
param([string]$falPath, [string]$expr)
Add-Type -AssemblyName System.Drawing

function Load($p) {
  $b = New-Object System.Drawing.Bitmap((Resolve-Path $p).Path)
  $w = $b.Width; $h = $b.Height
  $r = New-Object System.Drawing.Rectangle 0, 0, $w, $h
  $d = $b.LockBits($r, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $by = New-Object byte[] ($d.Stride * $h)
  [System.Runtime.InteropServices.Marshal]::Copy($d.Scan0, $by, 0, $by.Length)
  $b.UnlockBits($d); $b.Dispose()
  [pscustomobject]@{ W = $w; H = $h; S = $d.Stride; B = $by }
}
function Save($img, $p) {
  $b = New-Object System.Drawing.Bitmap $img.W, $img.H, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $r = New-Object System.Drawing.Rectangle 0, 0, $img.W, $img.H
  $d = $b.LockBits($r, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  [System.Runtime.InteropServices.Marshal]::Copy($img.B, 0, $d.Scan0, $img.B.Length)
  $b.UnlockBits($d)
  $b.Save((Join-Path (Get-Location).Path $p), [System.Drawing.Imaging.ImageFormat]::Png); $b.Dispose()
}
function Eyes($img, $x0, $x1, $y0, $y1, $thr) {
  $cxm = [int](($x0 + $x1) / 2)
  $sLx = 0; $sLy = 0; $nL = 0; $sRx = 0; $sRy = 0; $nR = 0
  for ($y = $y0; $y -le $y1; $y++) {
    $row = $y * $img.S
    for ($x = $x0; $x -le $x1; $x++) {
      $i = $row + $x * 4
      if ($img.B[$i + 3] -lt 128) { continue }
      $br = ($img.B[$i] + $img.B[$i + 1] + $img.B[$i + 2]) / 3
      if ($br -lt $thr) { if ($x -lt $cxm) { $sLx += $x; $sLy += $y; $nL += 1 } else { $sRx += $x; $sRy += $y; $nR += 1 } }
    }
  }
  [pscustomobject]@{ Lx = $sLx / $nL; Ly = $sLy / $nL; Rx = $sRx / $nR; Ry = $sRy / $nR }
}

$master = Load "images\parts\yada_master.png"
$base   = Load "images\parts\yada_noeyes.png"
$fal    = Load $falPath

# eye box in MASTER coords
$bx0 = 490; $bx1 = 790; $by0 = 198; $by1 = 292
$me = Eyes $master $bx0 $bx1 $by0 $by1 100
$fe = Eyes $fal 475 805 188 305 100
$mDist = [Math]::Sqrt([Math]::Pow($me.Rx - $me.Lx, 2) + [Math]::Pow($me.Ry - $me.Ly, 2))
$fDist = [Math]::Sqrt([Math]::Pow($fe.Rx - $fe.Lx, 2) + [Math]::Pow($fe.Ry - $fe.Ly, 2))
$scale = $mDist / $fDist
$mmx = ($me.Lx + $me.Rx) / 2; $mmy = ($me.Ly + $me.Ry) / 2
$fmx = ($fe.Lx + $fe.Rx) / 2; $fmy = ($fe.Ly + $fe.Ry) / 2
Write-Host ("master eyes mid({0:N0},{1:N0}) dist={2:N0} ; fal mid({3:N0},{4:N0}) dist={5:N0} ; scale={6:N3}" -f $mmx, $mmy, $mDist, $fmx, $fmy, $fDist, $scale)

$eyePart = [pscustomobject]@{ W = $master.W; H = $master.H; S = $master.S; B = (New-Object byte[] $master.B.Length) }
$kept = 0
for ($by = $by0; $by -le $by1; $by++) {
  for ($bx = $bx0; $bx -le $bx1; $bx++) {
    $fx = [int][Math]::Round($fmx + ($bx - $mmx) / $scale)
    $fy = [int][Math]::Round($fmy + ($by - $mmy) / $scale)
    if ($fx -lt 0 -or $fy -lt 0 -or $fx -ge $fal.W -or $fy -ge $fal.H) { continue }
    $fi = $fy * $fal.S + $fx * 4
    if ($fal.B[$fi + 3] -lt 128) { continue }
    $b = $fal.B[$fi]; $g = $fal.B[$fi + 1]; $r = $fal.B[$fi + 2]; $br = ($r + $g + $b) / 3
    $isSkin = (($r - $b) -gt 45) -and ($br -ge 150) -and ($br -le 245)
    if ($isSkin) { continue }
    $oi = $by * $eyePart.S + $bx * 4
    $eyePart.B[$oi] = $b; $eyePart.B[$oi + 1] = $g; $eyePart.B[$oi + 2] = $r; $eyePart.B[$oi + 3] = 255
    $kept += 1
  }
}
Write-Host "eye-part feature px=$kept"

# composite over base
$comp = [pscustomobject]@{ W = $base.W; H = $base.H; S = $base.S; B = $base.B.Clone() }
for ($i = 0; $i -lt $comp.B.Length; $i += 4) {
  if ($eyePart.B[$i + 3] -ge 128) { $comp.B[$i] = $eyePart.B[$i]; $comp.B[$i + 1] = $eyePart.B[$i + 1]; $comp.B[$i + 2] = $eyePart.B[$i + 2]; $comp.B[$i + 3] = 255 }
}
Save $eyePart ("images\parts\yada_eyes_" + $expr + ".png")
Save $comp ("_expr_" + $expr + ".png")
Write-Host ("saved images/parts/yada_eyes_" + $expr + ".png and _expr_" + $expr + ".png")

# Make an eyes+brows expression part by RECOGNIZING the connected eye/brow shapes
# (border-exclusion flood fill, not a per-pixel color test alone), aligned to the
# master via HEAD SILHOUETTE bounding box (not eye centroid -- robust for closed eyes).
# Output: images/parts/yada_eyes_<expr>.png (transparent, shape-only) + _expr_<expr>.png (preview composite)
# usage: powershell -File tools\make_expression.ps1 <falImage.png> <expr> [char]
# char selects the per-character geometry table below (default: yada). Run from repo root.
param([string]$falPath, [string]$expr, [string]$char = "yada")
Add-Type -AssemblyName System.Drawing

# Per-character measured geometry (window must sit in a verified skin gap -- see
# character-art-pipeline memory for the measurement method; do not guess these).
$CHAR_GEOM = @{
  "yada" = @{ Wx0 = 490; Wx1 = 765; Wy0 = 160; Wy1 = 325; Skin = @(254, 216, 175) }
  # hero's hairline and the eyebrow's pointed tip occupy overlapping x/y ranges at
  # different rows -- no rectangular window has a clean skin margin on every side
  # (verified by per-pixel sampling), so this one uses seeded growth instead of
  # border-exclusion. Seeds are solidly-interior points in each brow/eye (verified
  # non-skin), window below is just a generous safety clip, not a margin-dependent edge.
  "hero" = @{ Wx0 = 540; Wx1 = 870; Wy0 = 190; Wy1 = 340; Skin = @(252, 204, 164)
              # 3rd value = vertical snap bias: -1 brow (prefer up, avoid snapping
              # onto an enlarged "surprised" eye that sits closer), +1 eye (prefer down)
              Seeds = @(@(613,240,-1), @(795,240,-1), @(615,290,1), @(793,290,1), @(689,278,0), @(719,278,0)) }
}
if (-not $CHAR_GEOM.ContainsKey($char)) { throw "unknown char '$char' -- add its geometry to `$CHAR_GEOM first" }
$geom = $CHAR_GEOM[$char]
$masterPath = "images\parts\$char`_master.png"
$noeyesOutPath = "images\parts\$char`_noeyes.png"
$eyesOutPath = "images\parts\$char`_eyes_$expr.png"

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
# fal.ai raw output is often 24bpp (no real alpha) with a near-white flattened
# background. Border-flood-fill near-white pixels to derive a true alpha mask.
function StripWhiteBg($img) {
  $w = $img.W; $h = $img.H; $n = $w * $h
  $isBgColor = New-Object bool[] $n
  for ($y = 0; $y -lt $h; $y++) {
    $row = $y * $img.S
    for ($x = 0; $x -lt $w; $x++) {
      $i = $row + $x * 4
      $b = $img.B[$i]; $g = $img.B[$i + 1]; $r = $img.B[$i + 2]
      $mx = [Math]::Max($r, [Math]::Max($g, $b)); $mn = [Math]::Min($r, [Math]::Min($g, $b))
      if (($mx - $mn) -le 20 -and $mx -ge 195) { $isBgColor[$y * $w + $x] = $true }
    }
  }
  $bg = New-Object bool[] $n
  $stack = New-Object 'System.Collections.Generic.Stack[int]'
  for ($x = 0; $x -lt $w; $x++) {
    if ($isBgColor[$x]) { $bg[$x] = $true; $stack.Push($x) }
    $bi = ($h - 1) * $w + $x; if ($isBgColor[$bi]) { $bg[$bi] = $true; $stack.Push($bi) }
  }
  for ($y = 0; $y -lt $h; $y++) {
    $li = $y * $w; $ri = $y * $w + ($w - 1)
    if ($isBgColor[$li]) { $bg[$li] = $true; $stack.Push($li) }
    if ($isBgColor[$ri]) { $bg[$ri] = $true; $stack.Push($ri) }
  }
  while ($stack.Count -gt 0) {
    $p = $stack.Pop(); $py = [int][Math]::Floor($p / $w); $px = $p - $py * $w
    if ($px -gt 0)      { $np = $p - 1;  if ($isBgColor[$np] -and -not $bg[$np]) { $bg[$np] = $true; $stack.Push($np) } }
    if ($px -lt $w - 1) { $np = $p + 1;  if ($isBgColor[$np] -and -not $bg[$np]) { $bg[$np] = $true; $stack.Push($np) } }
    if ($py -gt 0)      { $np = $p - $w; if ($isBgColor[$np] -and -not $bg[$np]) { $bg[$np] = $true; $stack.Push($np) } }
    if ($py -lt $h - 1) { $np = $p + $w; if ($isBgColor[$np] -and -not $bg[$np]) { $bg[$np] = $true; $stack.Push($np) } }
  }
  $cnt = 0
  for ($y = 0; $y -lt $h; $y++) {
    $row = $y * $img.S
    for ($x = 0; $x -lt $w; $x++) {
      if ($bg[$y * $w + $x]) { $img.B[$row + $x * 4 + 3] = 0; $cnt += 1 }
    }
  }
  Write-Host "StripWhiteBg: $cnt px -> transparent"
}

function IsSkin($img, $i) {
  if ($img.B[$i + 3] -lt 128) { return $false }
  $b = $img.B[$i]; $g = $img.B[$i + 1]; $r = $img.B[$i + 2]; $br = ($r + $g + $b) / 3
  return (($r - $b) -gt 45) -and ($br -ge 150) -and ($br -le 245)
}

# Largest connected opaque component (8-connected). Discards isolated noise specks
# (e.g. single stray non-background pixels) that would otherwise poison a bbox scan.
function LargestComponentMask($img) {
  $w = $img.W; $h = $img.H; $n = $w * $h
  $opaque = New-Object bool[] $n
  for ($y = 0; $y -lt $h; $y++) {
    $row = $y * $img.S
    for ($x = 0; $x -lt $w; $x++) { if ($img.B[$row + $x * 4 + 3] -gt 128) { $opaque[$y * $w + $x] = $true } }
  }
  $visited = New-Object bool[] $n
  $bestMask = $null; $bestCount = 0
  $stack = New-Object 'System.Collections.Generic.Stack[int]'
  for ($s = 0; $s -lt $n; $s++) {
    if (-not $opaque[$s] -or $visited[$s]) { continue }
    $comp = New-Object 'System.Collections.Generic.List[int]'
    $visited[$s] = $true; $stack.Push($s)
    while ($stack.Count -gt 0) {
      $p = $stack.Pop(); $comp.Add($p)
      $py = [int][Math]::Floor($p / $w); $px = $p - $py * $w
      # additive (not py*w+px) neighbor offsets -- avoids amplifying any row/col
      # reconstruction error into a completely wrong flat index.
      if ($px -gt 0)                       { $np = $p - 1;      if ($opaque[$np] -and -not $visited[$np]) { $visited[$np] = $true; $stack.Push($np) } }
      if ($px -lt $w - 1)                  { $np = $p + 1;      if ($opaque[$np] -and -not $visited[$np]) { $visited[$np] = $true; $stack.Push($np) } }
      if ($py -gt 0)                       { $np = $p - $w;     if ($opaque[$np] -and -not $visited[$np]) { $visited[$np] = $true; $stack.Push($np) } }
      if ($py -lt $h - 1)                  { $np = $p + $w;     if ($opaque[$np] -and -not $visited[$np]) { $visited[$np] = $true; $stack.Push($np) } }
      if ($px -gt 0 -and $py -gt 0)        { $np = $p - $w - 1; if ($opaque[$np] -and -not $visited[$np]) { $visited[$np] = $true; $stack.Push($np) } }
      if ($px -lt $w - 1 -and $py -gt 0)   { $np = $p - $w + 1; if ($opaque[$np] -and -not $visited[$np]) { $visited[$np] = $true; $stack.Push($np) } }
      if ($px -gt 0 -and $py -lt $h - 1)   { $np = $p + $w - 1; if ($opaque[$np] -and -not $visited[$np]) { $visited[$np] = $true; $stack.Push($np) } }
      if ($px -lt $w - 1 -and $py -lt $h - 1) { $np = $p + $w + 1; if ($opaque[$np] -and -not $visited[$np]) { $visited[$np] = $true; $stack.Push($np) } }
    }
    if ($comp.Count -gt $bestCount) { $bestCount = $comp.Count; $bestMask = $comp }
  }
  $mask = New-Object bool[] $n
  foreach ($p in $bestMask) { $mask[$p] = $true }
  $noise = 0
  for ($k = 0; $k -lt $n; $k++) { if ($opaque[$k] -and -not $mask[$k]) { $noise += 1 } }
  Write-Host "LargestComponentMask: kept $bestCount px, discarded $noise px noise"
  [pscustomobject]@{ W = $w; H = $h; Mask = $mask }
}
# Zero the alpha of any opaque pixel outside the largest connected component,
# so isolated noise specks can't poison later bbox/silhouette scans.
function CleanToLargestComponent($img) {
  $lc = LargestComponentMask $img
  for ($y = 0; $y -lt $img.H; $y++) {
    $row = $y * $img.S
    for ($x = 0; $x -lt $img.W; $x++) {
      $i = $row + $x * 4
      if ($img.B[$i + 3] -gt 128 -and -not $lc.Mask[$y * $img.W + $x]) { $img.B[$i + 3] = 0 }
    }
  }
}

# --- 1) HEAD SILHOUETTE bounding box (auto-detect the neck pinch, then bbox above it) ---
function HeadBBox($img) {
  $w = $img.W; $h = $img.H
  $halfWidth = New-Object int[] $h
  $minXrow = New-Object int[] $h
  $maxXrow = New-Object int[] $h
  for ($y = 0; $y -lt $h; $y++) {
    $row = $y * $img.S; $mn = -1; $mx = -1
    for ($x = 0; $x -lt $w; $x++) {
      if ($img.B[$row + $x * 4 + 3] -gt 128) { if ($mn -lt 0) { $mn = $x }; $mx = $x }
    }
    $minXrow[$y] = $mn; $maxXrow[$y] = $mx
    $halfWidth[$y] = if ($mx -ge 0) { ($mx - $mn) } else { 99999 }
  }
  # neck = local minimum width row within the upper 20%-65% of the silhouette height
  $top = 0; for ($y = 0; $y -lt $h; $y++) { if ($minXrow[$y] -ge 0) { $top = $y; break } }
  $bot = $h - 1; for ($y = $h - 1; $y -ge 0; $y--) { if ($minXrow[$y] -ge 0) { $bot = $y; break } }
  $searchLo = $top + [int](($bot - $top) * 0.18)
  $searchHi = $top + [int](($bot - $top) * 0.60)
  $neckY = $searchLo; $neckW = 999999
  for ($y = $searchLo; $y -le $searchHi; $y++) {
    if ($minXrow[$y] -ge 0 -and $halfWidth[$y] -lt $neckW) { $neckW = $halfWidth[$y]; $neckY = $y }
  }
  $hx0 = $w; $hx1 = -1
  for ($y = $top; $y -le $neckY; $y++) { if ($minXrow[$y] -ge 0) { if ($minXrow[$y] -lt $hx0) { $hx0 = $minXrow[$y] }; if ($maxXrow[$y] -gt $hx1) { $hx1 = $maxXrow[$y] } } }
  [pscustomobject]@{ X0 = $hx0; X1 = $hx1; Y0 = $top; Y1 = $neckY; W = ($hx1 - $hx0); H = ($neckY - $top) }
}

# --- 2b) RECOGNITION (seeded): flood-fill from known-good interior seed points,
#         through non-skin pixels, clipped to the window. Robust when the window
#         has NO clean skin margin on some side (e.g. hairline and a brow's pointed
#         tip occupy the same x/y range at different rows -- border-exclusion can't
#         find a safe edge in that case, but seeded growth doesn't need one: hair
#         touching the window edge simply doesn't matter unless it's reachable from
#         a seed placed inside the brow/eye itself.
function RecognizeFeatureSeeded($img, $x0, $x1, $y0, $y1, $seeds) {
  $bw = $x1 - $x0 + 1; $bh = $y1 - $y0 + 1
  $nonSkin = New-Object bool[] ($bw * $bh)
  for ($y = $y0; $y -le $y1; $y++) {
    $row = $y * $img.S
    for ($x = $x0; $x -le $x1; $x++) {
      $i = $row + $x * 4
      if ($img.B[$i + 3] -ge 128 -and -not (IsSkin $img $i)) { $nonSkin[($y - $y0) * $bw + ($x - $x0)] = $true }
    }
  }
  $mask = New-Object bool[] ($bw * $bh)
  $stack = New-Object 'System.Collections.Generic.Stack[int]'
  $snapR = 28  # seed snap radius: an expression can shift a feature (raised brow,
               # closed-eye crescent) away from where it sits in the base/master --
               # snap each seed to the nearest non-skin pixel within this radius
               # instead of requiring it to already be exactly on the feature.
  foreach ($s in $seeds) {
    $sx = [int][Math]::Round($s[0]) - $x0; $sy = [int][Math]::Round($s[1]) - $y0
    if ($sx -lt 0 -or $sy -lt 0 -or $sx -ge $bw -or $sy -ge $bh) { continue }
    # optional 3rd element biases the snap search vertically: -1 = prefer upward
    # (brow seeds -- an enlarged "surprised" eye can sit closer than the real brow,
    # so an unbiased nearest-snap grabs the eye instead), +1 = prefer downward
    # (eye seeds), 0/absent = search both ways equally.
    $bias = if ($s.Count -ge 3) { $s[2] } else { 0 }
    $dyLo = if ($bias -gt 0) { [int](-$snapR * 0.2) } else { -$snapR }
    $dyHi = if ($bias -lt 0) { [int]($snapR * 0.2) } else { $snapR }
    $sp = $sy * $bw + $sx
    if (-not $nonSkin[$sp]) {
      $bestD = [double]::MaxValue; $bestP = -1
      for ($dy = $dyLo; $dy -le $dyHi; $dy++) {
        $ny = $sy + $dy; if ($ny -lt 0 -or $ny -ge $bh) { continue }
        for ($dx = -$snapR; $dx -le $snapR; $dx++) {
          $nx = $sx + $dx; if ($nx -lt 0 -or $nx -ge $bw) { continue }
          if (-not $nonSkin[$ny * $bw + $nx]) { continue }
          $dd = $dx * $dx + $dy * $dy
          if ($dd -lt $bestD) { $bestD = $dd; $bestP = $ny * $bw + $nx }
        }
      }
      if ($bestP -lt 0) { Write-Host "  seed ($($s[0]),$($s[1])) -> local($sx,$sy) NO snap found in radius $snapR"; continue }
      $bpy = [int][Math]::Floor($bestP / $bw); $bpx = $bestP - $bpy * $bw
      Write-Host "  seed ($($s[0]),$($s[1])) -> local($sx,$sy) snapped to local($bpx,$bpy) = abs($($bpx+$x0),$($bpy+$y0)) dist=$([Math]::Sqrt($bestD))"
      $sp = $bestP
    }
    if ($mask[$sp]) { continue }
    $mask[$sp] = $true; $stack.Push($sp)
    while ($stack.Count -gt 0) {
      $p = $stack.Pop(); $py = [int][Math]::Floor($p / $bw); $px = $p - $py * $bw
      if ($px -gt 0)        { $np = $p - 1;  if ($nonSkin[$np] -and -not $mask[$np]) { $mask[$np] = $true; $stack.Push($np) } }
      if ($px -lt $bw - 1)  { $np = $p + 1;  if ($nonSkin[$np] -and -not $mask[$np]) { $mask[$np] = $true; $stack.Push($np) } }
      if ($py -gt 0)        { $np = $p - $bw; if ($nonSkin[$np] -and -not $mask[$np]) { $mask[$np] = $true; $stack.Push($np) } }
      if ($py -lt $bh - 1)  { $np = $p + $bw; if ($nonSkin[$np] -and -not $mask[$np]) { $mask[$np] = $true; $stack.Push($np) } }
      if ($px -gt 0 -and $py -gt 0)             { $np = $p - $bw - 1; if ($nonSkin[$np] -and -not $mask[$np]) { $mask[$np] = $true; $stack.Push($np) } }
      if ($px -lt $bw - 1 -and $py -gt 0)       { $np = $p - $bw + 1; if ($nonSkin[$np] -and -not $mask[$np]) { $mask[$np] = $true; $stack.Push($np) } }
      if ($px -gt 0 -and $py -lt $bh - 1)       { $np = $p + $bw - 1; if ($nonSkin[$np] -and -not $mask[$np]) { $mask[$np] = $true; $stack.Push($np) } }
      if ($px -lt $bw - 1 -and $py -lt $bh - 1) { $np = $p + $bw + 1; if ($nonSkin[$np] -and -not $mask[$np]) { $mask[$np] = $true; $stack.Push($np) } }
    }
  }
  $cnt = 0; for ($k = 0; $k -lt $mask.Length; $k++) { if ($mask[$k]) { $cnt += 1 } }
  [pscustomobject]@{ Mask = $mask; X0 = $x0; Y0 = $y0; BW = $bw; BH = $bh; Count = $cnt }
}

# --- 2) RECOGNITION: connected non-skin region inside a window, excluding anything
#        that touches the window border (border-flood marks "leaked into hair/outside").
function RecognizeFeature($img, $x0, $x1, $y0, $y1) {
  $w = $img.W; $h = $img.H
  $bw = $x1 - $x0 + 1; $bh = $y1 - $y0 + 1
  $nonSkin = New-Object bool[] ($bw * $bh)
  for ($y = $y0; $y -le $y1; $y++) {
    $row = $y * $img.S
    for ($x = $x0; $x -le $x1; $x++) {
      $i = $row + $x * 4
      if ($img.B[$i + 3] -ge 128 -and -not (IsSkin $img $i)) { $nonSkin[($y - $y0) * $bw + ($x - $x0)] = $true }
    }
  }
  $leaked = New-Object bool[] ($bw * $bh)
  $stack = New-Object 'System.Collections.Generic.Stack[int]'
  for ($x = 0; $x -lt $bw; $x++) {
    if ($nonSkin[$x]) { $leaked[$x] = $true; $stack.Push($x) }
    $bi = ($bh - 1) * $bw + $x
    if ($nonSkin[$bi]) { $leaked[$bi] = $true; $stack.Push($bi) }
  }
  for ($y = 0; $y -lt $bh; $y++) {
    $li = $y * $bw; $ri = $y * $bw + ($bw - 1)
    if ($nonSkin[$li]) { $leaked[$li] = $true; $stack.Push($li) }
    if ($nonSkin[$ri]) { $leaked[$ri] = $true; $stack.Push($ri) }
  }
  while ($stack.Count -gt 0) {
    $p = $stack.Pop(); $py = [int][Math]::Floor($p / $bw); $px = $p - $py * $bw
    if ($px -gt 0)      { $np = $p - 1;  if ($nonSkin[$np] -and -not $leaked[$np]) { $leaked[$np] = $true; $stack.Push($np) } }
    if ($px -lt $bw - 1) { $np = $p + 1;  if ($nonSkin[$np] -and -not $leaked[$np]) { $leaked[$np] = $true; $stack.Push($np) } }
    if ($py -gt 0)      { $np = $p - $bw; if ($nonSkin[$np] -and -not $leaked[$np]) { $leaked[$np] = $true; $stack.Push($np) } }
    if ($py -lt $bh - 1) { $np = $p + $bw; if ($nonSkin[$np] -and -not $leaked[$np]) { $leaked[$np] = $true; $stack.Push($np) } }
  }
  # recognized = non-skin AND NOT reached from the border (i.e. fully enclosed shapes)
  $rawMask = New-Object bool[] ($bw * $bh)
  for ($k = 0; $k -lt $nonSkin.Length; $k++) { if ($nonSkin[$k] -and -not $leaked[$k]) { $rawMask[$k] = $true } }

  # drop small connected components (stray generation noise/specks) -- real eye/brow
  # shapes are large; isolated dots a few pixels wide are not a recognized feature.
  $visited2 = New-Object bool[] ($bw * $bh)
  $mask = New-Object bool[] ($bw * $bh)
  $cnt = 0
  $stack2 = New-Object 'System.Collections.Generic.Stack[int]'
  for ($s = 0; $s -lt $rawMask.Length; $s++) {
    if (-not $rawMask[$s] -or $visited2[$s]) { continue }
    $comp = New-Object 'System.Collections.Generic.List[int]'
    $visited2[$s] = $true; $stack2.Push($s)
    while ($stack2.Count -gt 0) {
      $p2 = $stack2.Pop(); $comp.Add($p2)
      $py2 = [int][Math]::Floor($p2 / $bw); $px2 = $p2 - $py2 * $bw
      if ($px2 -gt 0)        { $np2 = $p2 - 1;  if ($rawMask[$np2] -and -not $visited2[$np2]) { $visited2[$np2] = $true; $stack2.Push($np2) } }
      if ($px2 -lt $bw - 1)  { $np2 = $p2 + 1;  if ($rawMask[$np2] -and -not $visited2[$np2]) { $visited2[$np2] = $true; $stack2.Push($np2) } }
      if ($py2 -gt 0)        { $np2 = $p2 - $bw; if ($rawMask[$np2] -and -not $visited2[$np2]) { $visited2[$np2] = $true; $stack2.Push($np2) } }
      if ($py2 -lt $bh - 1)  { $np2 = $p2 + $bw; if ($rawMask[$np2] -and -not $visited2[$np2]) { $visited2[$np2] = $true; $stack2.Push($np2) } }
      if ($px2 -gt 0 -and $py2 -gt 0)             { $np2 = $p2 - $bw - 1; if ($rawMask[$np2] -and -not $visited2[$np2]) { $visited2[$np2] = $true; $stack2.Push($np2) } }
      if ($px2 -lt $bw - 1 -and $py2 -gt 0)       { $np2 = $p2 - $bw + 1; if ($rawMask[$np2] -and -not $visited2[$np2]) { $visited2[$np2] = $true; $stack2.Push($np2) } }
      if ($px2 -gt 0 -and $py2 -lt $bh - 1)       { $np2 = $p2 + $bw - 1; if ($rawMask[$np2] -and -not $visited2[$np2]) { $visited2[$np2] = $true; $stack2.Push($np2) } }
      if ($px2 -lt $bw - 1 -and $py2 -lt $bh - 1) { $np2 = $p2 + $bw + 1; if ($rawMask[$np2] -and -not $visited2[$np2]) { $visited2[$np2] = $true; $stack2.Push($np2) } }
    }
    if ($comp.Count -lt 25) { continue }
    # nose/mouth guard: eyes+brows are bilateral (clearly left-of-center or
    # right-of-center); a component centered on the midline and in the lower
    # part of the window is nose/mouth territory (e.g. fal drew a nose despite
    # being told not to) -- reject it even though it passed the size filter.
    $cMinX = $bw; $cMaxX = -1; $cMinY = $bh; $cMaxY = -1
    foreach ($p2 in $comp) {
      $cy = [int][Math]::Floor($p2 / $bw); $cx = $p2 - $cy * $bw
      if ($cx -lt $cMinX) { $cMinX = $cx }; if ($cx -gt $cMaxX) { $cMaxX = $cx }
      if ($cy -lt $cMinY) { $cMinY = $cy }; if ($cy -gt $cMaxY) { $cMaxY = $cy }
    }
    $compCx = ($cMinX + $cMaxX) / 2.0; $compCy = ($cMinY + $cMaxY) / 2.0
    $midX = $bw / 2.0
    $isCentered = [Math]::Abs($compCx - $midX) -lt ($bw * 0.12)
    $isLow = $compCy -gt ($bh * 0.62)
    if ($isCentered -and $isLow) { continue }
    foreach ($p2 in $comp) { $mask[$p2] = $true; $cnt += 1 }
  }
  [pscustomobject]@{ Mask = $mask; X0 = $x0; Y0 = $y0; BW = $bw; BH = $bh; Count = $cnt }
}

# grow a recognized mask by $radius px so anti-aliased boundary pixels (blended
# toward skin color, just inside the "isSkin" threshold) get covered too -- avoids
# a faint ghost outline surviving the skin-fill at the mask's edge.
function DilateMask($feat, $radius) {
  $bw = $feat.BW; $bh = $feat.BH
  $newMask = New-Object bool[] ($bw * $bh)
  for ($y = 0; $y -lt $bh; $y++) {
    for ($x = 0; $x -lt $bw; $x++) {
      if ($feat.Mask[$y * $bw + $x]) { $newMask[$y * $bw + $x] = $true; continue }
      $found = $false
      for ($dy = -$radius; $dy -le $radius -and -not $found; $dy++) {
        for ($dx = -$radius; $dx -le $radius -and -not $found; $dx++) {
          $nx = $x + $dx; $ny = $y + $dy
          if ($nx -ge 0 -and $ny -ge 0 -and $nx -lt $bw -and $ny -lt $bh -and $feat.Mask[$ny * $bw + $nx]) { $found = $true }
        }
      }
      if ($found) { $newMask[$y * $bw + $x] = $true }
    }
  }
  $cnt = 0; for ($k = 0; $k -lt $newMask.Length; $k++) { if ($newMask[$k]) { $cnt += 1 } }
  [pscustomobject]@{ Mask = $newMask; X0 = $feat.X0; Y0 = $feat.Y0; BW = $bw; BH = $bh; Count = $cnt }
}

$master = Load $masterPath
$fal    = Load $falPath
StripWhiteBg $fal
CleanToLargestComponent $fal

$mHead = HeadBBox $master
$fHead = HeadBBox $fal
Write-Host ("master head bbox x[{0}..{1}] y[{2}..{3}]  (w={4} h={5})" -f $mHead.X0, $mHead.X1, $mHead.Y0, $mHead.Y1, $mHead.W, $mHead.H)
Write-Host ("fal    head bbox x[{0}..{1}] y[{2}..{3}]  (w={4} h={5})" -f $fHead.X0, $fHead.X1, $fHead.Y0, $fHead.Y1, $fHead.W, $fHead.H)

$scale = (($mHead.W / $fHead.W) + ($mHead.H / $fHead.H)) / 2.0
$mCx = ($mHead.X0 + $mHead.X1) / 2.0; $mCy = ($mHead.Y0 + $mHead.Y1) / 2.0
$fCx = ($fHead.X0 + $fHead.X1) / 2.0; $fCy = ($fHead.Y0 + $fHead.Y1) / 2.0
Write-Host ("scale={0:N3}  masterHeadCenter({1:N0},{2:N0}) falHeadCenter({3:N0},{4:N0})" -f $scale, $mCx, $mCy, $fCx, $fCy)

# search window for the eyes+brows shape, in MASTER coords (per-character, measured -- see $CHAR_GEOM above)
$wx0 = $geom.Wx0; $wx1 = $geom.Wx1; $wy0 = $geom.Wy0; $wy1 = $geom.Wy1

# recognize the shape directly in the master (used to build the noppera-bou base + the "base" expression part)
if ($geom.Seeds) { $mFeat = RecognizeFeatureSeeded $master $wx0 $wx1 $wy0 $wy1 $geom.Seeds }
else { $mFeat = RecognizeFeature $master $wx0 $wx1 $wy0 $wy1 }
$mFeat = DilateMask $mFeat 3
Write-Host "master recognized feature px = $($mFeat.Count) (dilated)"
$mDbg = New-Object System.Drawing.Bitmap $mFeat.BW, $mFeat.BH
$mdg = [System.Drawing.Graphics]::FromImage($mDbg); $mdg.Clear([System.Drawing.Color]::White); $mdg.Dispose()
for ($yy = 0; $yy -lt $mFeat.BH; $yy++) { for ($xx = 0; $xx -lt $mFeat.BW; $xx++) { if ($mFeat.Mask[$yy * $mFeat.BW + $xx]) { $mDbg.SetPixel($xx, $yy, [System.Drawing.Color]::Red) } } }
$mDbg.Save((Join-Path (Get-Location).Path ("_dbgmask_" + $char + "_master.png")), [System.Drawing.Imaging.ImageFormat]::Png); $mDbg.Dispose()

# recognize the shape in the fal output: map the master window into fal coords first
function ToFal($mx, $my) { @( ($fCx + ($mx - $mCx) / $scale), ($fCy + ($my - $mCy) / $scale) ) }
$c1 = ToFal $wx0 $wy0; $c2 = ToFal $wx1 $wy1
$fwx0 = [int][Math]::Floor([Math]::Min($c1[0], $c2[0])) - 4
$fwx1 = [int][Math]::Ceiling([Math]::Max($c1[0], $c2[0])) + 4
$fwy0 = [int][Math]::Floor([Math]::Min($c1[1], $c2[1])) - 4
$fwy1 = [int][Math]::Ceiling([Math]::Max($c1[1], $c2[1])) + 4
if ($geom.Seeds) {
  $fSeeds = @(); foreach ($s in $geom.Seeds) { $ft = ToFal $s[0] $s[1]; $bias = if ($s.Count -ge 3) { $s[2] } else { 0 }; $fSeeds += , @($ft[0], $ft[1], $bias) }
  $fFeat = RecognizeFeatureSeeded $fal $fwx0 $fwx1 $fwy0 $fwy1 $fSeeds
} else {
  $fFeat = RecognizeFeature $fal $fwx0 $fwx1 $fwy0 $fwy1
}
$fFeat = DilateMask $fFeat 1
Write-Host "fal recognized feature px = $($fFeat.Count) (dilated)  (window x[$fwx0..$fwx1] y[$fwy0..$fwy1])"

# DEBUG: dump the raw recognized mask (fal-space, no transform) at native resolution
$dbgMask = New-Object System.Drawing.Bitmap $fFeat.BW, $fFeat.BH
$dg = [System.Drawing.Graphics]::FromImage($dbgMask); $dg.Clear([System.Drawing.Color]::White); $dg.Dispose()
for ($yy = 0; $yy -lt $fFeat.BH; $yy++) {
  for ($xx = 0; $xx -lt $fFeat.BW; $xx++) {
    if ($fFeat.Mask[$yy * $fFeat.BW + $xx]) { $dbgMask.SetPixel($xx, $yy, [System.Drawing.Color]::Red) }
  }
}
$dbgMask.Save((Join-Path (Get-Location).Path ("_dbgmask_" + $char + "_" + $expr + ".png")), [System.Drawing.Imaging.ImageFormat]::Png)
$dbgMask.Dispose()

# build the eyes+brows part on the master canvas: for every MASTER pixel in the window,
# map to fal coords and keep it iff that fal pixel is part of the recognized fal feature.
$eyePart = [pscustomobject]@{ W = $master.W; H = $master.H; S = $master.S; B = (New-Object byte[] $master.B.Length) }
$kept = 0
for ($by = $wy0; $by -le $wy1; $by++) {
  for ($bx = $wx0; $bx -le $wx1; $bx++) {
    $f = ToFal $bx $by
    $fx = [int][Math]::Round($f[0]); $fy = [int][Math]::Round($f[1])
    if ($fx -lt $fwx0 -or $fy -lt $fwy0 -or $fx -gt $fwx1 -or $fy -gt $fwy1) { continue }
    $mi = ($fy - $fwy0) * $fFeat.BW + ($fx - $fwx0)
    if (-not $fFeat.Mask[$mi]) { continue }
    $fi = $fy * $fal.S + $fx * 4
    $oi = $by * $eyePart.S + $bx * 4
    $eyePart.B[$oi] = $fal.B[$fi]; $eyePart.B[$oi + 1] = $fal.B[$fi + 1]; $eyePart.B[$oi + 2] = $fal.B[$fi + 2]; $eyePart.B[$oi + 3] = 255
    $kept += 1
  }
}
Write-Host "eye-part placed px = $kept"
Save $eyePart ("_dbgpart_" + $char + "_" + $expr + ".png")

# noppera-bou base: master with its OWN recognized eyes+brows shape skin-filled
$SKIN = $geom.Skin
$noeyes = [pscustomobject]@{ W = $master.W; H = $master.H; S = $master.S; B = $master.B.Clone() }
for ($by = $wy0; $by -le $wy1; $by++) {
  for ($bx = $wx0; $bx -le $wx1; $bx++) {
    $mi = ($by - $wy0) * $mFeat.BW + ($bx - $wx0)
    if (-not $mFeat.Mask[$mi]) { continue }
    $oi = $by * $noeyes.S + $bx * 4
    $noeyes.B[$oi] = $SKIN[2]; $noeyes.B[$oi + 1] = $SKIN[1]; $noeyes.B[$oi + 2] = $SKIN[0]; $noeyes.B[$oi + 3] = 255
  }
}
Save $noeyes $noeyesOutPath

# composite preview
$comp = [pscustomobject]@{ W = $noeyes.W; H = $noeyes.H; S = $noeyes.S; B = $noeyes.B.Clone() }
for ($i = 0; $i -lt $comp.B.Length; $i += 4) {
  if ($eyePart.B[$i + 3] -ge 128) { $comp.B[$i] = $eyePart.B[$i]; $comp.B[$i + 1] = $eyePart.B[$i + 1]; $comp.B[$i + 2] = $eyePart.B[$i + 2]; $comp.B[$i + 3] = 255 }
}
Save $eyePart $eyesOutPath
Save $comp ("_expr_" + $char + "_" + $expr + ".png")
Write-Host ("saved " + $eyesOutPath + " and _expr_" + $char + "_" + $expr + ".png")

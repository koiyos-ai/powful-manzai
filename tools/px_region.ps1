# px_region.ps1 - Extract image region as editable text grid
# Usage: powershell -ExecutionPolicy Bypass -File tools\px_region.ps1 -src _pxv2_hero_base.png -rx 100 -ry 10 -rw 30 -rh 55 -out _grid.txt
# ASCII only / Windows PowerShell 5.1 compatible
param(
  [string]$src,
  [int]$rx, [int]$ry, [int]$rw, [int]$rh,
  [string]$out = "_grid.txt"
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$srcPath = Join-Path $root $src
if (-not (Test-Path $srcPath)) { Write-Error "not found: $srcPath"; exit 1 }

$img = [System.Drawing.Bitmap]::FromFile($srcPath)
$imgW = $img.Width; $imgH = $img.Height
$rect = New-Object System.Drawing.Rectangle 0,0,$imgW,$imgH
$bd = $img.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$bytes = New-Object byte[] ($bd.Stride * $imgH)
[System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $bytes, 0, $bytes.Length)
$stride = $bd.Stride
$img.UnlockBits($bd); $img.Dispose()

# Collect unique colors in region
$colorMap = @{}  # packed_int -> count
for ($y = $ry; $y -lt ($ry + $rh); $y++) {
  if ($y -lt 0 -or $y -ge $imgH) { continue }
  for ($x = $rx; $x -lt ($rx + $rw); $x++) {
    if ($x -lt 0 -or $x -ge $imgW) { continue }
    $o = $y * $stride + $x * 4
    $a = [int]$bytes[$o+3]
    if ($a -lt 128) { continue }
    $r = [int]$bytes[$o+2]; $g = [int]$bytes[$o+1]; $b = [int]$bytes[$o]
    $key = ($r -shl 16) -bor ($g -shl 8) -bor $b
    if ($colorMap.ContainsKey($key)) { $colorMap[$key]++ } else { $colorMap[$key] = 1 }
  }
}

# Classify color into category
function ColorCat([int]$r,[int]$g,[int]$b) {
  $mx = [math]::Max($r,[math]::Max($g,$b))
  $mn = [math]::Min($r,[math]::Min($g,$b))
  if ($mx -lt 50) { return "K" }
  if ($mn -gt 210) { return "W" }
  if (($mx-$mn) -lt 30 -and $mx -ge 50) { return "G" }
  if ($r -gt 150 -and $g -lt 80 -and $b -lt 80) {
    if ($r -gt 220) { return "R" } else { return "r" }
  }
  if ($r -gt 160 -and $g -gt 90 -and $b -gt 50 -and $r -gt $g -and $g -gt $b) {
    if ($g -gt 170) { return "S" } elseif ($g -gt 130) { return "s" } else { return "n" }
  }
  if ($r -gt 180 -and $g -gt 150 -and $b -lt 100) { return "Y" }
  if ($r -gt 60 -and $r -lt 180 -and $g -gt 20 -and $g -lt 110 -and $b -lt 70 -and $r -gt $g) { return "B" }
  if ($b -gt $r -and $b -gt $g -and $b -gt 100) { return "U" }
  if ($b -gt 100 -and $g -gt 100 -and $r -gt 100) { return "L" }
  return "X"
}

# Variant chars for each category (case-sensitive dictionary)
$catVariants = New-Object 'System.Collections.Generic.Dictionary[string,string[]]'
$catVariants.Add("K", @("K","1","2"))
$catVariants.Add("W", @("W","w","3"))
$catVariants.Add("G", @("G","g","4","5"))
$catVariants.Add("R", @("R","E","e","6"))
$catVariants.Add("r", @("r","d","D","7"))
$catVariants.Add("S", @("S","8","9"))
$catVariants.Add("s", @("s","0","A"))
$catVariants.Add("n", @("n","N","F"))
$catVariants.Add("Y", @("Y","y","C"))
$catVariants.Add("B", @("B","b","H"))
$catVariants.Add("U", @("U","u","I"))
$catVariants.Add("L", @("L","l","J"))
$catVariants.Add("X", @("X","x","z","q","p","m","t","v","f","h","c","a","i","j"))

# Sort colors by frequency desc, assign chars
$sortedKeys = New-Object int[] $colorMap.Count
$sortedVals = New-Object int[] $colorMap.Count
$idx = 0
foreach ($kk in $colorMap.Keys) { $sortedKeys[$idx]=[int]$kk; $sortedVals[$idx]=[int]$colorMap[$kk]; $idx++ }
[array]::Sort($sortedVals, $sortedKeys)
[array]::Reverse($sortedKeys); [array]::Reverse($sortedVals)

$charForColor = @{}   # packed_int -> char
$colorForChar = New-Object 'System.Collections.Generic.Dictionary[string,int]'
$catUsed = New-Object 'System.Collections.Generic.Dictionary[string,int]'

for ($i = 0; $i -lt $sortedKeys.Length; $i++) {
  $key = $sortedKeys[$i]
  $cr = ($key -shr 16) -band 255
  $cg = ($key -shr 8) -band 255
  $cb = $key -band 255
  $cat = ColorCat $cr $cg $cb
  $ci = 0
  if ($catUsed.ContainsKey($cat)) { $ci = $catUsed[$cat] }
  $variants = $catVariants[$cat]
  if (-not $variants) { $variants = $catVariants["X"] }
  if ($ci -ge $variants.Length) { $ci = $variants.Length - 1 }
  $ch = $variants[$ci]
  # Handle collision: if char already used, try next
  while ($colorForChar.ContainsKey($ch)) {
    $ci++
    if ($ci -lt $variants.Length) { $ch = $variants[$ci] }
    else { $ch = [string][char](33 + $colorForChar.Count); break }
  }
  $charForColor[$key] = $ch
  $colorForChar[$ch] = $key
  $catUsed[$cat] = $ci + 1
}

# Build output
$lines = New-Object System.Collections.ArrayList
[void]$lines.Add("# px_region grid - edit and feed to px_paint.ps1")
[void]$lines.Add("# src=$src region=($rx,$ry ${rw}x${rh})")
[void]$lines.Add("PALETTE:")
[void]$lines.Add(". = transparent")
for ($i = 0; $i -lt $sortedKeys.Length; $i++) {
  $key = $sortedKeys[$i]
  $cr = ($key -shr 16) -band 255
  $cg = ($key -shr 8) -band 255
  $cb = $key -band 255
  $ch = $charForColor[$key]
  [void]$lines.Add("$ch = rgb($cr,$cg,$cb) x$($sortedVals[$i])")
}
[void]$lines.Add("GRID:")

for ($y = $ry; $y -lt ($ry + $rh); $y++) {
  $row = ""
  for ($x = $rx; $x -lt ($rx + $rw); $x++) {
    if ($x -lt 0 -or $x -ge $imgW -or $y -lt 0 -or $y -ge $imgH) { $row += "."; continue }
    $o = $y * $stride + $x * 4
    $a = [int]$bytes[$o+3]
    if ($a -lt 128) { $row += "."; continue }
    $r2 = [int]$bytes[$o+2]; $g2 = [int]$bytes[$o+1]; $b2 = [int]$bytes[$o]
    $key = ($r2 -shl 16) -bor ($g2 -shl 8) -bor $b2
    if ($charForColor.ContainsKey($key)) { $row += $charForColor[$key] }
    else { $row += "?" }
  }
  [void]$lines.Add($row)
}

$outPath = Join-Path $root $out
$lines -join "`n" | Out-File -FilePath $outPath -Encoding utf8
Write-Host ("wrote {0} ({1} colors, {2}x{3} grid)" -f $out, $colorMap.Count, $rw, $rh)

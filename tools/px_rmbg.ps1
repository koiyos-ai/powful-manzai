# px_rmbg.ps1 - Remove baked-in checkered background via flood-fill from corners.
param(
  [string]$src = "images\yada_source.png",
  [string]$out = "_yada_nobg.png"
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root $src))) { $root = (Get-Location).Path }
$srcPath = Join-Path $root $src
$outPath = Join-Path $root $out

$orig = [System.Drawing.Bitmap]::FromFile($srcPath)
$ww = $orig.Width; $hh = $orig.Height
Write-Host "source: ${ww}x${hh}"

# Create new 32bpp ARGB bitmap (guaranteed alpha support)
$img = New-Object System.Drawing.Bitmap $ww, $hh, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g0 = [System.Drawing.Graphics]::FromImage($img)
$g0.DrawImage($orig, 0, 0, $ww, $hh)
$g0.Dispose()
$orig.Dispose()

# Read pixels
$rect = New-Object System.Drawing.Rectangle 0, 0, $ww, $hh
$bd = $img.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$bytes = New-Object byte[] ($bd.Stride * $hh)
[System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $bytes, 0, $bytes.Length)
$stride = $bd.Stride

# BFS flood-fill from edges: mark background pixels as transparent
$visited = New-Object bool[] ($ww * $hh)
$queue = New-Object System.Collections.Generic.Queue[int]

# Seed from all edge pixels
for ($x = 0; $x -lt $ww; $x++) {
  # top edge
  $idx = $x
  if (-not $visited[$idx]) { $visited[$idx] = $true; $queue.Enqueue($idx) }
  # bottom edge
  $idx = ($hh-1)*$ww + $x
  if (-not $visited[$idx]) { $visited[$idx] = $true; $queue.Enqueue($idx) }
}
for ($y = 1; $y -lt $hh-1; $y++) {
  $idx = $y * $ww
  if (-not $visited[$idx]) { $visited[$idx] = $true; $queue.Enqueue($idx) }
  $idx = $y * $ww + $ww - 1
  if (-not $visited[$idx]) { $visited[$idx] = $true; $queue.Enqueue($idx) }
}

$removed = 0
while ($queue.Count -gt 0) {
  $idx = $queue.Dequeue()
  $cx = $idx % $ww; $cy = [int][math]::Floor($idx / $ww)
  $o = $cy * $stride + $cx * 4
  $b0 = $bytes[$o]; $g0 = $bytes[$o+1]; $r0 = $bytes[$o+2]; $a0 = $bytes[$o+3]
  # Background test: grayish (R~G~B, spread < 25) and bright (avg > 160), or already transparent
  $mx = [math]::Max($r0, [math]::Max($g0, $b0))
  $mn = [math]::Min($r0, [math]::Min($g0, $b0))
  $spread = $mx - $mn
  $avg = [int](($r0 + $g0 + $b0) / 3)
  $isBg = ($a0 -lt 128) -or ($spread -lt 25 -and $avg -gt 160)
  if (-not $isBg) { continue }
  # Make transparent
  $bytes[$o] = 0; $bytes[$o+1] = 0; $bytes[$o+2] = 0; $bytes[$o+3] = 0
  $removed++
  # 4-neighbors
  if ($cx -gt 0) { $n = $idx-1; if (-not $visited[$n]) { $visited[$n]=$true; $queue.Enqueue($n) } }
  if ($cx -lt $ww-1) { $n = $idx+1; if (-not $visited[$n]) { $visited[$n]=$true; $queue.Enqueue($n) } }
  if ($cy -gt 0) { $n = $idx-$ww; if (-not $visited[$n]) { $visited[$n]=$true; $queue.Enqueue($n) } }
  if ($cy -lt $hh-1) { $n = $idx+$ww; if (-not $visited[$n]) { $visited[$n]=$true; $queue.Enqueue($n) } }
}

[System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $bd.Scan0, $bytes.Length)
$img.UnlockBits($bd)
$img.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
$img.Dispose()
Write-Host "removed ${removed} background pixels, wrote ${out}"

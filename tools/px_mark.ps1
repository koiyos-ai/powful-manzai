# px_mark.ps1 - render a dot-list file as a highlight over the base sprite.
# Usage: powershell -ExecutionPolicy Bypass -File tools\px_mark.ps1 -dots _dots_brow_L.txt -out _mark_brow_L.png [-base _pxv2_hero_base.png]
# Dots file format (see _DOTSPEC.md):
#   DOTS:                 -> green highlight
#   y=58: 152-153 160     -> ranges and single columns
#   AMBIGUOUS:            -> orange highlight
#   y=64: 154-164 @shared-with:eye_L reason...
# Validation: any listed dot that is transparent in the base is reported as ERROR.
param(
  [string]$dots,
  [string]$out,
  [string]$base = "_pxv2_hero_base.png",
  [int]$zoom = 8
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot

function ParseSection($lines, $section) {
  $res = New-Object System.Collections.ArrayList
  $inSec = $false
  foreach ($l in $lines) {
    $t = $l.Trim()
    if ($t -eq "$section`:") { $inSec = $true; continue }
    if ($t -match "^[A-Z]+:$") { $inSec = $false; continue }
    if (-not $inSec -or $t -eq "" -or $t.StartsWith("#")) { continue }
    if ($t -match "^y=(\d+):\s*(.*)$") {
      $y = [int]$Matches[1]
      $spec = $Matches[2]
      $at = $spec.IndexOf('@'); if ($at -ge 0) { $spec = $spec.Substring(0,$at) }
      foreach ($tok in ($spec -split '\s+')) {
        if ($tok -eq "") { continue }
        if ($tok -match "^(\d+)-(\d+)$") {
          for ($x=[int]$Matches[1]; $x -le [int]$Matches[2]; $x++) { [void]$res.Add(@($x,$y)) }
        } elseif ($tok -match "^(\d+)$") {
          [void]$res.Add(@([int]$Matches[1],$y))
        } else {
          Write-Host "WARN: unparsed token '$tok' in $section y=$y"
        }
      }
    }
  }
  return ,$res
}

$dl = Get-Content (Join-Path $root $dots) -Encoding UTF8
$main = ParseSection $dl "DOTS"
$amb  = ParseSection $dl "AMBIGUOUS"
$sh = ParseSection $dl "SHARED"
foreach ($d in $sh) { [void]$amb.Add($d) }
Write-Host ("dots: {0} main + {1} ambiguous" -f $main.Count, $amb.Count)

$img = [System.Drawing.Bitmap]::FromFile((Join-Path $root $base))
$W=$img.Width; $H=$img.Height
# validation + bbox
$minX=99999;$maxX=-1;$minY=99999;$maxY=-1; $bad=0
foreach ($grp in @($main,$amb)) {
  foreach ($d in $grp) {
    $x=$d[0]; $y=$d[1]
    if ($x -lt 0 -or $x -ge $W -or $y -lt 0 -or $y -ge $H) { Write-Host "ERROR: out of canvas ($x,$y)"; $bad++; continue }
    if ($img.GetPixel($x,$y).A -lt 128) { Write-Host "ERROR: transparent dot listed ($x,$y)"; $bad++ }
    if($x -lt $minX){$minX=$x}; if($x -gt $maxX){$maxX=$x}
    if($y -lt $minY){$minY=$y}; if($y -gt $maxY){$maxY=$y}
  }
}
if ($bad -gt 0) { Write-Host "VALIDATION FAILED: $bad bad dots"; }
$minX=[math]::Max(0,$minX-6); $minY=[math]::Max(0,$minY-6)
$maxX=[math]::Min($W-1,$maxX+6); $maxY=[math]::Min($H-1,$maxY+6)
$cw=$maxX-$minX+1; $ch=$maxY-$minY+1

$crop = New-Object System.Drawing.Bitmap $cw,$ch
$g = [System.Drawing.Graphics]::FromImage($crop)
$g.DrawImage($img,(New-Object System.Drawing.Rectangle 0,0,$cw,$ch),(New-Object System.Drawing.Rectangle $minX,$minY,$cw,$ch),[System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose(); $img.Dispose()
foreach ($d in $main) { $crop.SetPixel($d[0]-$minX,$d[1]-$minY,[System.Drawing.Color]::FromArgb(255,0,220,80)) }
foreach ($d in $amb)  { $crop.SetPixel($d[0]-$minX,$d[1]-$minY,[System.Drawing.Color]::FromArgb(255,255,140,0)) }

$z = $zoom
while ($cw*$z -gt 1400 -and $z -gt 2) { $z-- }
$big = New-Object System.Drawing.Bitmap ($cw*$z),($ch*$z)
$g2=[System.Drawing.Graphics]::FromImage($big)
$g2.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g2.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::Half
$g2.DrawImage($crop,(New-Object System.Drawing.Rectangle 0,0,($cw*$z),($ch*$z)))
$g2.Dispose()
$big.Save((Join-Path $root $out),[System.Drawing.Imaging.ImageFormat]::Png)
$big.Dispose(); $crop.Dispose()
Write-Host "wrote $out (region $minX,$minY ${cw}x${ch} zoom x$z)"


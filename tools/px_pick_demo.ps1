# px_pick_demo.ps1 - exact dot enumeration demo: LEFT EYEBROW of _pxv2_hero_base.
# Enumerates every dark dot in the brow rows, prints coordinates+color per dot,
# and renders a highlight image (green=brow dots, orange=merge dots shared with eye outline).
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot

$lines = Get-Content (Join-Path $root "_pxmaster_hero.txt")
$gi=0; for ($i=0;$i -lt $lines.Count;$i++){ if ($lines[$i] -eq 'GRID:'){ $gi=$i+1; break } }

$darkChars = @('K','1','2','-','/','X','G','g')
$list = New-Object System.Collections.ArrayList
# brow rows y57..64, query window x143..166 (query only - membership is per exact dot)
for ($y=57; $y -le 64; $y++) {
  $row = $lines[$gi+$y]
  for ($x=143; $x -le 166; $x++) {
    $ch = [string]$row[$x]
    if ($darkChars -contains $ch) { [void]$list.Add(@($x,$y,$ch)) }
  }
}
Write-Host "left eyebrow: $($list.Count) dots"
$byRow = $list | Group-Object { $_[1] }
foreach ($grp in $byRow) {
  $xs = ($grp.Group | ForEach-Object { "$($_[0])$($_[2])" }) -join " "
  Write-Host ("y={0}: {1}" -f $grp.Name, $xs)
}

# merge dots: brow dots at y64 whose y+1 neighbor is also dark (connection to eye outline)
$mergeDots = New-Object System.Collections.ArrayList
$rowBelow = $lines[$gi+65]
foreach ($d in $list) {
  if ($d[1] -eq 64) {
    $chB = [string]$rowBelow[$d[0]]
    if ($darkChars -contains $chB) { [void]$mergeDots.Add(@($d[0],64)); [void]$mergeDots.Add(@($d[0],65)) }
  }
}
Write-Host "merge dots with eye outline: $($mergeDots.Count/2) columns"
foreach ($m in $mergeDots) { Write-Host ("  ({0},{1})" -f $m[0],$m[1]) }

# highlight render: base at 8x, brow dots green, merge dots orange
$img = [System.Drawing.Bitmap]::FromFile((Join-Path $root "_pxv2_hero_base.png"))
$crop = New-Object System.Drawing.Bitmap 60,30
$g = [System.Drawing.Graphics]::FromImage($crop)
$g.DrawImage($img,(New-Object System.Drawing.Rectangle 0,0,60,30),(New-Object System.Drawing.Rectangle 130,48,60,30),[System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose(); $img.Dispose()
# tint
for ($i=0;$i -lt $list.Count;$i++) {
  $d=$list[$i]; $cx=$d[0]-130; $cy=$d[1]-48
  if ($cx -ge 0 -and $cx -lt 60 -and $cy -ge 0 -and $cy -lt 30) { $crop.SetPixel($cx,$cy,[System.Drawing.Color]::FromArgb(255,0,220,80)) }
}
for ($i=0;$i -lt $mergeDots.Count;$i++) {
  $d=$mergeDots[$i]; $cx=$d[0]-130; $cy=$d[1]-48
  if ($cx -ge 0 -and $cx -lt 60 -and $cy -ge 0 -and $cy -lt 30) { $crop.SetPixel($cx,$cy,[System.Drawing.Color]::FromArgb(255,255,140,0)) }
}
$big = New-Object System.Drawing.Bitmap 600,300
$g2=[System.Drawing.Graphics]::FromImage($big)
$g2.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g2.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::Half
$g2.DrawImage($crop,(New-Object System.Drawing.Rectangle 0,0,600,300))
$g2.Dispose()
$big.Save((Join-Path $root "_pick_brow_demo.png"),[System.Drawing.Imaging.ImageFormat]::Png)
$big.Dispose(); $crop.Dispose()
Write-Host "wrote _pick_brow_demo.png"

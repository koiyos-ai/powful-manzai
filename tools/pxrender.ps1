# Renders a text pixel-map (1 char = 1 palette symbol) to a PNG using a fixed palette.
# Validates that every row has the same width. Also writes an NN-upscaled preview.
# Usage: powershell -File tools\pxrender.ps1 -map _pxmap_hero.txt -pal hero [-scale 8]
# ASCII only.
param(
  [Parameter(Mandatory=$true)][string]$map,
  [Parameter(Mandatory=$true)][string]$pal,
  [string]$out = "",
  [int]$scale = 8
)
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "pxpalettes.ps1")
if(-not $PXPAL.ContainsKey($pal)){ throw "unknown palette '$pal'" }
$P = $PXPAL[$pal]

$mapPath = $map
if(-not [System.IO.Path]::IsPathRooted($mapPath)){ $mapPath = Join-Path (Split-Path $PSScriptRoot -Parent) $map }
$lines = [System.IO.File]::ReadAllLines($mapPath) | Where-Object { $_ -ne $null }
# drop trailing empty lines
while($lines.Count -gt 0 -and $lines[$lines.Count-1].Trim().Length -eq 0){ $lines = $lines[0..($lines.Count-2)] }
$H = $lines.Count
$W = $lines[0].Length
for($y=0;$y -lt $H;$y++){
  if($lines[$y].Length -ne $W){ throw ("row {0} width {1} != {2}" -f $y,$lines[$y].Length,$W) }
}

$bm = New-Object System.Drawing.Bitmap $W,$H,([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$rect = New-Object System.Drawing.Rectangle 0,0,$W,$H
$data = $bm.LockBits($rect,[System.Drawing.Imaging.ImageLockMode]::WriteOnly,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$stride = $data.Stride
$buf = New-Object byte[] ($stride*$H)
for($y=0;$y -lt $H;$y++){
  $line = $lines[$y]
  for($x=0;$x -lt $W;$x++){
    $c = $line.Substring($x,1)
    if(-not $P.ContainsKey($c)){ $bm.UnlockBits($data); throw ("row {0} col {1}: unknown symbol '{2}'" -f $y,$x,$c) }
    $rgba = $P[$c]
    $oi = $y*$stride + $x*4
    $buf[$oi]   = [byte]$rgba[2]
    $buf[$oi+1] = [byte]$rgba[1]
    $buf[$oi+2] = [byte]$rgba[0]
    $buf[$oi+3] = [byte]$rgba[3]
  }
}
[System.Runtime.InteropServices.Marshal]::Copy($buf,0,$data.Scan0,$buf.Length)
$bm.UnlockBits($data)

if($out -eq ""){ $out = [System.IO.Path]::ChangeExtension($mapPath,".png") }
if(-not [System.IO.Path]::IsPathRooted($out)){ $out = Join-Path (Split-Path $PSScriptRoot -Parent) $out }
$bm.Save($out,[System.Drawing.Imaging.ImageFormat]::Png)

# NN preview
if($scale -gt 1){
  $big = New-Object System.Drawing.Bitmap ($W*$scale),($H*$scale),([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($big)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
  $g.DrawImage($bm,0,0,($W*$scale),($H*$scale))
  $g.Dispose()
  $bigOut = [System.IO.Path]::ChangeExtension($out,$null) + "_big.png"
  $big.Save($bigOut,[System.Drawing.Imaging.ImageFormat]::Png)
  $big.Dispose()
  Write-Host ("rendered {0}  ({1}x{2})  + preview {3}" -f (Split-Path $out -Leaf),$W,$H,(Split-Path $bigOut -Leaf))
} else {
  Write-Host ("rendered {0}  ({1}x{2})" -f (Split-Path $out -Leaf),$W,$H)
}
$bm.Dispose()

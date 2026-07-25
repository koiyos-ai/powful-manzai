# px_paint.ps1 - Composite a text grid onto a base image
# Usage: powershell -ExecutionPolicy Bypass -File tools\px_paint.ps1 -base _pxv2_hero_base.png -grid _grid.txt -out _result.png [-preview 4]
# Grid file format: PALETTE section (char = rgb(R,G,B)), then GRID section (text rows).
# . = set transparent, _ = keep original pixel unchanged, other chars = set to palette color.
# ASCII only / Windows PowerShell 5.1 compatible
param(
  [string]$base,
  [string]$grid,
  [string]$out,
  [int]$preview = 4
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$basePath = Join-Path $root $base
$gridPath = Join-Path $root $grid
if (-not (Test-Path $basePath)) { Write-Error "base not found: $basePath"; exit 1 }
if (-not (Test-Path $gridPath)) { Write-Error "grid not found: $gridPath"; exit 1 }

# Parse grid file
$rawLines = [System.IO.File]::ReadAllLines($gridPath)
$palette = New-Object 'System.Collections.Generic.Dictionary[string,int[]]'
$gridRows = New-Object System.Collections.ArrayList
$regionX = 0; $regionY = 0
$inPalette = $false; $inGrid = $false

foreach ($line in $rawLines) {
  if ($line -match "^#.*region=\((\d+),(\d+)") {
    $regionX = [int]$Matches[1]; $regionY = [int]$Matches[2]
  }
  if ($line -eq "PALETTE:") { $inPalette = $true; $inGrid = $false; continue }
  if ($line -eq "GRID:") { $inGrid = $true; $inPalette = $false; continue }
  if ($inPalette) {
    if ($line -match "^(.) = rgb\((\d+),(\d+),(\d+)\)") {
      $ch = $Matches[1]
      $palette[$ch] = @([int]$Matches[2], [int]$Matches[3], [int]$Matches[4])
    }
  }
  if ($inGrid -and $line.Length -gt 0 -and $line[0] -ne '#') {
    [void]$gridRows.Add($line)
  }
}

$gridH = $gridRows.Count
$gridW = 0
if ($gridH -gt 0) { $gridW = $gridRows[0].Length }
Write-Host ("grid: {0}x{1} at ({2},{3}), palette: {4} colors" -f $gridW,$gridH,$regionX,$regionY,$palette.Count)

# Load base image
$srcImg = [System.Drawing.Bitmap]::FromFile($basePath)
$imgW = $srcImg.Width; $imgH = $srcImg.Height
$dst = New-Object System.Drawing.Bitmap $imgW,$imgH,([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$gfx = [System.Drawing.Graphics]::FromImage($dst)
$gfx.DrawImage($srcImg, 0, 0, $imgW, $imgH)
$gfx.Dispose(); $srcImg.Dispose()

$rect = New-Object System.Drawing.Rectangle 0,0,$imgW,$imgH
$bd = $dst.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$px = New-Object byte[] ($bd.Stride * $imgH)
[System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $px, 0, $px.Length)
$st = $bd.Stride

$painted = 0; $cleared = 0; $kept = 0
for ($gy = 0; $gy -lt $gridH; $gy++) {
  $row = $gridRows[$gy]
  for ($gx = 0; $gx -lt $row.Length; $gx++) {
    $ch = [string]$row[$gx]
    $ix = $regionX + $gx; $iy = $regionY + $gy
    if ($ix -lt 0 -or $ix -ge $imgW -or $iy -lt 0 -or $iy -ge $imgH) { continue }
    $o = $iy * $st + $ix * 4
    if ($ch -eq "_") { $kept++; continue }
    if ($ch -eq ".") {
      $px[$o]=0; $px[$o+1]=0; $px[$o+2]=0; $px[$o+3]=0
      $cleared++; continue
    }
    if ($palette.ContainsKey($ch)) {
      $c = $palette[$ch]
      $px[$o]=[byte]$c[2]; $px[$o+1]=[byte]$c[1]; $px[$o+2]=[byte]$c[0]; $px[$o+3]=255
      $painted++
    } else {
      Write-Host ("warning: unknown char '$ch' at grid ($gx,$gy)")
    }
  }
}
Write-Host ("painted=$painted cleared=$cleared kept=$kept")

# Save
[System.Runtime.InteropServices.Marshal]::Copy($px, 0, $bd.Scan0, $px.Length)
$dst.UnlockBits($bd)
$outPath = Join-Path $root $out
$dst.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)

# Preview
if ($preview -gt 1) {
  $big = New-Object System.Drawing.Bitmap ($imgW*$preview),($imgH*$preview)
  $gb = [System.Drawing.Graphics]::FromImage($big)
  $gb.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
  $gb.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
  $gb.DrawImage($dst, (New-Object System.Drawing.Rectangle 0,0,($imgW*$preview),($imgH*$preview)))
  $gb.Dispose()
  $bigPath = $outPath -replace "\.png$","_big.png"
  $big.Save($bigPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $big.Dispose()
  Write-Host ("preview: " + (Split-Path -Leaf $bigPath))
}
$dst.Dispose()
Write-Host "done: $out"

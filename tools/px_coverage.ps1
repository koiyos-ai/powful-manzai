# px_coverage.ps1 - verify that the union of all _dots_*.txt files covers every
# opaque dot of the base exactly once (AMBIGUOUS shared dots may appear in 2 files).
# Reports: orphan dots (opaque but in no file), duplicate DOTS claims, and stats.
# Renders _coverage_gaps.png (red = orphans, yellow = duplicate-claimed).
param(
  [string]$base = "_pxv2_hero_base.png"
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot

# owner map: dotIndex -> list of "part(kind)" claims
$W=352; $H=192
$claims = New-Object 'object[]' ($W*$H)

function AddClaim([int]$x,[int]$y,[string]$tag) {
  $i = $y*352+$x
  if ($null -eq $script:claims[$i]) { $script:claims[$i] = New-Object System.Collections.ArrayList }
  [void]$script:claims[$i].Add($tag)
}

$files = Get-ChildItem (Join-Path $root "_dots_*.txt") | Sort-Object Name
Write-Host "found $($files.Count) dots files"
foreach ($f in $files) {
  $part = $f.BaseName -replace '^_dots_',''
  $lines = Get-Content $f.FullName -Encoding UTF8
  $sec = ""
  foreach ($l in $lines) {
    $t = $l.Trim()
    if ($t -eq "DOTS:") { $sec="D"; continue }
    if ($t -eq "AMBIGUOUS:") { $sec="A"; continue }
    if ($t -eq "SHARED:") { $sec="A"; continue }
    if ($t -eq "" -or $t.StartsWith("#")) { continue }
    if ($t -match "^y=(\d+):\s*(.*)$") {
      $y=[int]$Matches[1]; $spec=$Matches[2]
      $at=$spec.IndexOf('@'); if ($at -ge 0) { $spec=$spec.Substring(0,$at) }
      foreach ($tok in ($spec -split '\s+')) {
        if ($tok -eq "") { continue }
        if ($tok -match "^(\d+)-(\d+)$") { for($x=[int]$Matches[1];$x -le [int]$Matches[2];$x++){ AddClaim $x $y "$part($sec)" } }
        elseif ($tok -match "^(\d+)$") { AddClaim ([int]$Matches[1]) $y "$part($sec)" }
      }
    }
  }
}

$img = [System.Drawing.Bitmap]::FromFile((Join-Path $root $base))
$orphans = New-Object System.Collections.ArrayList
$dupes = New-Object System.Collections.ArrayList
$phantom = 0
$covered = 0
for ($y=0;$y -lt $H;$y++) { for ($x=0;$x -lt $W;$x++) {
  $i=$y*352+$x
  $op = ($img.GetPixel($x,$y).A -ge 128)
  $cl = $claims[$i]
  if ($op) {
    if ($null -eq $cl) { [void]$orphans.Add(@($x,$y)) }
    else {
      $covered++
      # duplicates: more than one D-claim (A-claims may overlap by design)
      $dCount = 0
      foreach ($c in $cl) { if ($c.EndsWith("(D)")) { $dCount++ } }
      if ($dCount -gt 1) { [void]$dupes.Add(@($x,$y,($cl -join "+"))) }
    }
  } else {
    if ($null -ne $cl) { $phantom++ }
  }
}}
Write-Host ("covered opaque dots: {0}" -f $covered)
Write-Host ("orphans (opaque, unclaimed): {0}" -f $orphans.Count)
Write-Host ("duplicate DOTS claims: {0}" -f $dupes.Count)
Write-Host ("phantom claims on transparent dots: {0}" -f $phantom)
if ($orphans.Count -gt 0) {
  Write-Host "first orphans:"
  $orphans | Select-Object -First 25 | ForEach-Object { Write-Host ("  ({0},{1})" -f $_[0],$_[1]) }
}
if ($dupes.Count -gt 0) {
  Write-Host "first duplicates:"
  $dupes | Select-Object -First 25 | ForEach-Object { Write-Host ("  ({0},{1}) {2}" -f $_[0],$_[1],$_[2]) }
}

# gap render
$dst = New-Object System.Drawing.Bitmap $W,$H
$g=[System.Drawing.Graphics]::FromImage($dst)
$g.DrawImage($img,0,0,$W,$H); $g.Dispose()
# dim covered
for ($y=0;$y -lt $H;$y++) { for ($x=0;$x -lt $W;$x++) {
  $p = $dst.GetPixel($x,$y)
  if ($p.A -ge 128) {
    $gray=[int](($p.R+$p.G+$p.B)/3)
    $dst.SetPixel($x,$y,[System.Drawing.Color]::FromArgb(255,$gray,$gray,$gray))
  }
}}
foreach ($d in $orphans) { $dst.SetPixel($d[0],$d[1],[System.Drawing.Color]::FromArgb(255,255,0,0)) }
foreach ($d in $dupes)   { $dst.SetPixel($d[0],$d[1],[System.Drawing.Color]::FromArgb(255,255,255,0)) }
$big = New-Object System.Drawing.Bitmap ($W*4),($H*4)
$g2=[System.Drawing.Graphics]::FromImage($big)
$g2.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g2.DrawImage($dst,(New-Object System.Drawing.Rectangle 0,0,($W*4),($H*4)))
$g2.Dispose()
$big.Save((Join-Path $root "_coverage_gaps.png"),[System.Drawing.Imaging.ImageFormat]::Png)
$big.Dispose(); $dst.Dispose(); $img.Dispose()
Write-Host "wrote _coverage_gaps.png (red=orphan yellow=duplicate)"


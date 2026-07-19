# px_cc.ps1 - outline-first region decomposition (user-proposed method 2026-07-17).
# 1) classify dark line-colors as the "line network"
# 2) connected components (4-neighbor) of the remaining fill dots = enclosed regions
# 3) report each region (id, size, bbox, colors) + render a colorized map for review
# Scope: dots NOT already claimed by the approved head files.
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot

# --- load master map ---
$mm = Get-Content (Join-Path $root "_pxmaster_hero.txt")
$gi=0; for ($i=0;$i -lt $mm.Count;$i++){ if ($mm[$i] -eq 'GRID:'){ $gi=$i+1; break } }
$W=352; $H=192

# --- head-claimed dots (excluded from this analysis) ---
$headFiles = @("_dots_hair.txt","_dots_face.txt","_dots_ear_L.txt","_dots_ear_R.txt",
               "_dots_brow_L.txt","_dots_brow_R.txt","_dots_eye_L.txt","_dots_eye_R.txt")
$head = New-Object bool[] ($W*$H)
foreach ($hf in $headFiles) {
  $p = Join-Path $root $hf
  if (-not (Test-Path $p)) { continue }
  foreach ($l in (Get-Content $p -Encoding UTF8)) {
    $t=$l.Trim()
    if ($t -match "^y=(\d+):\s*(.*)$") {
      $y=[int]$Matches[1]; $spec=$Matches[2]
      $at=$spec.IndexOf('@'); if ($at -ge 0) { $spec=$spec.Substring(0,$at) }
      foreach ($tok in ($spec -split '\s+')) {
        if ($tok -match "^(\d+)-(\d+)$") { for($x=[int]$Matches[1];$x -le [int]$Matches[2];$x++){ $head[$y*$W+$x]=$true } }
        elseif ($tok -match "^(\d+)$") { $head[$y*$W+[int]$Matches[1]]=$true }
      }
    }
  }
}

# --- classify: 0=out, 1=line, 2=fill ---
# 2026-07-17 user directive: the outline is ONE unified black. In the ORIGINAL smooth
# illustration (images/hero.png) it truly is uniform black; the dot conversion dilutes
# some outline dots to near-black/dark-red. So recognize the outline WHERE IT IS UNIFORM
# (the hi-res source), then carry the mask down through the same 4x4 block reduction.
$src = [System.Drawing.Bitmap]::FromFile((Join-Path $root "images\hero.png"))
$sw=$src.Width; $sh=$src.Height   # 1408x768 = 4x the dot canvas
$srect = New-Object System.Drawing.Rectangle 0,0,$sw,$sh
$sbd = $src.LockBits($srect,[System.Drawing.Imaging.ImageLockMode]::ReadOnly,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$spx = New-Object byte[] ($sbd.Stride*$sh)
[System.Runtime.InteropServices.Marshal]::Copy($sbd.Scan0,$spx,0,$spx.Length)
$sst=$sbd.Stride; $src.UnlockBits($sbd); $src.Dispose()

$cls = New-Object byte[] ($W*$H)
$blackTol = 48   # hi-res outline is pure black; tolerance for anti-aliased edge pixels
for ($y=0;$y -lt $H;$y++) {
  $row = $mm[$gi+$y]
  for ($x=0;$x -lt $W;$x++) {
    $ch = [string]$row[$x]
    if ($ch -eq '.') { continue }
    if ($head[$y*$W+$x]) { continue }
    # count black pixels in the 4x4 source block of this dot
    $nBlack=0; $nOpq=0
    for ($by=0;$by -lt 4;$by++) { for ($bx=0;$bx -lt 4;$bx++) {
      $sx=$x*4+$bx; $sy=$y*4+$by
      if ($sx -ge $sw -or $sy -ge $sh) { continue }
      $o=$sy*$sst+$sx*4
      if ($spx[$o+3] -lt 128) { continue }
      $nOpq++
      $mx=[math]::Max([int]$spx[$o+2],[math]::Max([int]$spx[$o+1],[int]$spx[$o]))
      if ($mx -le $blackTol) { $nBlack++ }
    }}
    if ($nOpq -gt 0 -and $nBlack*2 -ge $nOpq) { $cls[$y*$W+$x] = 1 }   # black-majority block = line
    else { $cls[$y*$W+$x] = 2 }
  }
}

# --- connected components over fill dots (4-neighbor), iterative flood ---
$reg = New-Object int[] ($W*$H)   # 0 = none
$nextId = 0
$stack = New-Object System.Collections.Generic.Stack[int]
for ($y=0;$y -lt $H;$y++) {
  for ($x=0;$x -lt $W;$x++) {
    $i0 = $y*$W+$x
    if ($cls[$i0] -ne 2 -or $reg[$i0] -ne 0) { continue }
    $nextId++
    $stack.Push($i0)
    $reg[$i0] = $nextId
    while ($stack.Count -gt 0) {
      $i = $stack.Pop()
      $cy = [math]::Floor($i / $W); $cx = $i % $W
      foreach ($d in @(($i-1),($i+1),($i-$W),($i+$W))) {
        if ($d -lt 0 -or $d -ge $W*$H) { continue }
        # prevent wrap: x neighbors must share row
        if (($d -eq $i-1 -or $d -eq $i+1) -and ([math]::Floor($d/$W) -ne $cy)) { continue }
        if ($cls[$d] -eq 2 -and $reg[$d] -eq 0) { $reg[$d] = $nextId; $stack.Push($d) }
      }
    }
  }
}
Write-Host "regions found: $nextId"

# --- per-region stats ---
$size = New-Object int[] ($nextId+1)
$minX = New-Object int[] ($nextId+1); $maxX = New-Object int[] ($nextId+1)
$minY = New-Object int[] ($nextId+1); $maxY = New-Object int[] ($nextId+1)
for ($r=1;$r -le $nextId;$r++) { $minX[$r]=9999; $minY[$r]=9999; $maxX[$r]=-1; $maxY[$r]=-1 }
$colors = New-Object 'System.Collections.Generic.Dictionary[int,System.Collections.Generic.Dictionary[string,int]]'
for ($y=0;$y -lt $H;$y++) {
  $row = $mm[$gi+$y]
  for ($x=0;$x -lt $W;$x++) {
    $r = $reg[$y*$W+$x]
    if ($r -eq 0) { continue }
    $size[$r]++
    if($x -lt $minX[$r]){$minX[$r]=$x}; if($x -gt $maxX[$r]){$maxX[$r]=$x}
    if($y -lt $minY[$r]){$minY[$r]=$y}; if($y -gt $maxY[$r]){$maxY[$r]=$y}
    if (-not $colors.ContainsKey($r)) { $colors[$r] = New-Object 'System.Collections.Generic.Dictionary[string,int]' }
    $ch=[string]$row[$x]
    if ($colors[$r].ContainsKey($ch)) { $colors[$r][$ch]++ } else { $colors[$r][$ch]=1 }
  }
}
$repLines = New-Object System.Collections.ArrayList
[void]$repLines.Add("# region report (outline-first decomposition)")
for ($r=1;$r -le $nextId;$r++) {
  $cs = ($colors[$r].GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { "$($_.Key)x$($_.Value)" }) -join " "
  [void]$repLines.Add(("region {0}: size={1} bbox=({2},{3})-({4},{5}) colors: {6}" -f $r,$size[$r],$minX[$r],$minY[$r],$maxX[$r],$maxY[$r],$cs))
}
$repLines -join "`n" | Out-File (Join-Path $root "_cc_report.txt") -Encoding ascii

# --- save region id map (text) ---
$mapLines = New-Object System.Collections.ArrayList
[void]$mapLines.Add("# region id map: per row, runs of 'x1-x2:id'. line-network dots marked id=L")
for ($y=0;$y -lt $H;$y++) {
  $sb = New-Object System.Text.StringBuilder
  $runStart=-1; $runId=-999
  for ($x=0;$x -le $W;$x++) {
    $id = -1
    if ($x -lt $W) {
      $i=$y*$W+$x
      if ($cls[$i] -eq 1) { $id = -2 }        # line
      elseif ($reg[$i] -gt 0) { $id = $reg[$i] }
    }
    if ($id -ne $runId) {
      if ($runId -gt 0) { [void]$sb.Append(" $runStart-$($x-1):$runId") }
      elseif ($runId -eq -2) { [void]$sb.Append(" $runStart-$($x-1):L") }
      $runStart=$x; $runId=$id
    }
  }
  if ($sb.Length -gt 0) { [void]$mapLines.Add("y=$y$($sb.ToString())") }
}
$mapLines -join "`n" | Out-File (Join-Path $root "_cc_map.txt") -Encoding ascii

# --- render colorized region map ---
$palette = @(
  @(230,25,75),@(60,180,75),@(255,225,25),@(0,130,200),@(245,130,48),@(145,30,180),
  @(70,240,240),@(240,50,230),@(210,245,60),@(250,190,212),@(0,128,128),@(220,190,255),
  @(170,110,40),@(255,250,200),@(128,0,0),@(170,255,195),@(128,128,0),@(255,215,180),
  @(0,0,128),@(128,128,128),@(255,255,255),@(155,205,90),@(90,155,205),@(205,90,155)
)
$dst = New-Object System.Drawing.Bitmap $W,$H,([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
for ($y=0;$y -lt $H;$y++) { for ($x=0;$x -lt $W;$x++) {
  $i=$y*$W+$x
  if ($cls[$i] -eq 1) { $dst.SetPixel($x,$y,[System.Drawing.Color]::FromArgb(255,0,0,0)) }
  elseif ($reg[$i] -gt 0) {
    $c = $palette[($reg[$i]-1) % $palette.Count]
    $dst.SetPixel($x,$y,[System.Drawing.Color]::FromArgb(255,$c[0],$c[1],$c[2]))
  }
  elseif ($head[$i]) { $dst.SetPixel($x,$y,[System.Drawing.Color]::FromArgb(255,60,60,60)) }
}}
$big = New-Object System.Drawing.Bitmap ($W*4),($H*4)
$g2=[System.Drawing.Graphics]::FromImage($big)
$g2.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g2.DrawImage($dst,(New-Object System.Drawing.Rectangle 0,0,($W*4),($H*4)))
$g2.Dispose()
$big.Save((Join-Path $root "_cc_regions.png"),[System.Drawing.Imaging.ImageFormat]::Png)
$big.Dispose(); $dst.Dispose()
Write-Host "wrote _cc_report.txt / _cc_map.txt / _cc_regions.png"

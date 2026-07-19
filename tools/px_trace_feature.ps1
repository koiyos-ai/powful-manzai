# px_trace_feature.ps1 - trace a small drawn feature (button/flap) whose own outline
# is not pure black but a distinct dark rim color (X=56,24,24 / B=88,40,24), by doing
# a LOCAL outline-first decomposition exactly like px_cc.ps1 but scoped to a bbox and
# using {X,B} as the line network. Emits the rim (line) dots and the enclosed fill
# region(s) inside that bbox, plus a rendered zoom for visual QC.
param(
  [int]$rx, [int]$ry, [int]$rw, [int]$rh,
  [string]$name,
  [switch]$blob,        # blob mode: flood-fill the dark-shade class from a seed (button)
  [int]$seedX, [int]$seedY
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$W=352; $H=192

$mm = Get-Content (Join-Path $root "_pxmaster_hero.txt")
$gi=0; for ($i=0;$i -lt $mm.Count;$i++){ if ($mm[$i] -eq 'GRID:'){ $gi=$i+1; break } }

if ($blob) {
  # dark-shade class blob: the DEEP shadow tier only (X,B,2,/). D/d/r are the general
  # fold-shading language used broadly across the whole jacket (placket, lapel creases)
  # and over-grow if included - confirmed empirically (first attempt flooded the bbox).
  $darkChars = @('X','B','2','/')
  $cls = New-Object byte[] ($rw*$rh)
  for ($ly=0;$ly -lt $rh;$ly++) {
    $row = $mm[$gi+$ry+$ly]
    for ($lx=0;$lx -lt $rw;$lx++) {
      $ch=[string]$row[$rx+$lx]
      if ($ch -eq '.') { continue }
      if ($darkChars -contains $ch) { $cls[$ly*$rw+$lx]=1 }   # candidate dark
    }
  }
  $sly=$seedY-$ry; $slx=$seedX-$rx
  $blobMask = New-Object bool[] ($rw*$rh)
  if ($cls[$sly*$rw+$slx] -eq 1) {
    $stack = New-Object System.Collections.Generic.Stack[int]
    $stack.Push($sly*$rw+$slx); $blobMask[$sly*$rw+$slx]=$true
    while ($stack.Count -gt 0) {
      $i=$stack.Pop(); $cy=[math]::Floor($i/$rw); $cx=$i%$rw
      foreach ($d in @(@(-1,0),@(1,0),@(0,-1),@(0,1),@(-1,-1),@(1,-1),@(-1,1),@(1,1))) {
        $nx=$cx+$d[0]; $ny=$cy+$d[1]
        if ($nx -lt 0 -or $nx -ge $rw -or $ny -lt 0 -or $ny -ge $rh) { continue }
        $j=$ny*$rw+$nx
        if ($cls[$j] -eq 1 -and -not $blobMask[$j]) { $blobMask[$j]=$true; $stack.Push($j) }
      }
    }
  }
  # emit directly (blob mode skips the line/enclosed-fill logic below)
  $lines2 = New-Object System.Collections.ArrayList
  [void]$lines2.Add("# part: $name (traced via dark-shade blob flood-fill from seed ($seedX,$seedY), px_trace_feature.ps1 -blob)")
  [void]$lines2.Add("DOTS:")
  for ($ly=0;$ly -lt $rh;$ly++) {
    $sb = New-Object System.Text.StringBuilder
    $runS=-1
    for ($lx=0;$lx -le $rw;$lx++) {
      $isP = ($lx -lt $rw) -and $blobMask[$ly*$rw+$lx]
      if ($isP -and $runS -lt 0) { $runS=$lx }
      if (-not $isP -and $runS -ge 0) {
        $x0=$rx+$runS; $x1=$rx+$lx-1
        if ($x0 -eq $x1) { [void]$sb.Append(" $x0") } else { [void]$sb.Append(" $x0-$x1") }
        $runS=-1
      }
    }
    if ($sb.Length -gt 0) { [void]$lines2.Add("y=$($ry+$ly):$($sb.ToString())") }
  }
  $lines2 -join "`n" | Out-File (Join-Path $root "_trace_dots_$name.txt") -Encoding ascii
  $src = [System.Drawing.Bitmap]::FromFile((Join-Path $root "_pxv2_hero_base.png"))
  $crop = New-Object System.Drawing.Bitmap $rw,$rh
  $g=[System.Drawing.Graphics]::FromImage($crop)
  $g.DrawImage($src,(New-Object System.Drawing.Rectangle 0,0,$rw,$rh),(New-Object System.Drawing.Rectangle $rx,$ry,$rw,$rh),[System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose(); $src.Dispose()
  for ($ly=0;$ly -lt $rh;$ly++){ for ($lx=0;$lx -lt $rw;$lx++) { if ($blobMask[$ly*$rw+$lx]) { $crop.SetPixel($lx,$ly,[System.Drawing.Color]::FromArgb(255,0,220,80)) } } }
  $z=14
  $big = New-Object System.Drawing.Bitmap ($rw*$z),($rh*$z)
  $gb=[System.Drawing.Graphics]::FromImage($big)
  $gb.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
  $gb.DrawImage($crop,(New-Object System.Drawing.Rectangle 0,0,($rw*$z),($rh*$z)))
  $gb.Dispose()
  $big.Save((Join-Path $root "_trace_$name.png"),[System.Drawing.Imaging.ImageFormat]::Png)
  $big.Dispose(); $crop.Dispose()
  Write-Host "wrote _trace_$name.png and _trace_dots_$name.txt (blob mode)"
  return
}

$lineChars = @('X','B')
$cls = New-Object byte[] ($rw*$rh)     # 0 out, 1 line, 2 fill
for ($ly=0;$ly -lt $rh;$ly++) {
  $row = $mm[$gi+$ry+$ly]
  for ($lx=0;$lx -lt $rw;$lx++) {
    $ch = [string]$row[$rx+$lx]
    if ($ch -eq '.') { continue }
    if ($lineChars -contains $ch) { $cls[$ly*$rw+$lx]=1 } else { $cls[$ly*$rw+$lx]=2 }
  }
}
# connected components of fill (4-neighbor), restricted to bbox (outside bbox = wall,
# so a component that touches the bbox edge is "open"/leaked into the surrounding jacket)
$reg = New-Object int[] ($rw*$rh)
$nextId=0
$touchesEdge = New-Object 'System.Collections.Generic.Dictionary[int,bool]'
for ($ly=0;$ly -lt $rh;$ly++){ for ($lx=0;$lx -lt $rw;$lx++) {
  $i0=$ly*$rw+$lx
  if ($cls[$i0] -ne 2 -or $reg[$i0] -ne 0) { continue }
  $nextId++
  $stack = New-Object System.Collections.Generic.Stack[int]
  $stack.Push($i0); $reg[$i0]=$nextId
  $edge=$false
  while ($stack.Count -gt 0) {
    $i=$stack.Pop()
    $cy=[math]::Floor($i/$rw); $cx=$i%$rw
    if ($cx -eq 0 -or $cx -eq $rw-1 -or $cy -eq 0 -or $cy -eq $rh-1) { $edge=$true }
    foreach ($d in @(@(-1,0),@(1,0),@(0,-1),@(0,1))) {
      $nx=$cx+$d[0]; $ny=$cy+$d[1]
      if ($nx -lt 0 -or $nx -ge $rw -or $ny -lt 0 -or $ny -ge $rh) { continue }
      $j=$ny*$rw+$nx
      if ($cls[$j] -eq 2 -and $reg[$j] -eq 0) { $reg[$j]=$nextId; $stack.Push($j) }
    }
  }
  $touchesEdge[$nextId]=$edge
}}
Write-Host "$name : $nextId fill regions in bbox"
for ($r=1;$r -le $nextId;$r++) {
  $sz=0; for($i=0;$i -lt $rw*$rh;$i++){ if($reg[$i] -eq $r){$sz++} }
  Write-Host ("  region $r size=$sz touchesEdge=$($touchesEdge[$r])")
}

# render zoom with rim=black overlay tint, enclosed(non-edge-touching) regions=green,
# edge-touching (leaked into surrounding jacket) regions=unpainted (stay original color)
$src = [System.Drawing.Bitmap]::FromFile((Join-Path $root "_pxv2_hero_base.png"))
$crop = New-Object System.Drawing.Bitmap $rw,$rh
$g=[System.Drawing.Graphics]::FromImage($crop)
$g.DrawImage($src,(New-Object System.Drawing.Rectangle 0,0,$rw,$rh),(New-Object System.Drawing.Rectangle $rx,$ry,$rw,$rh),[System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose(); $src.Dispose()
for ($ly=0;$ly -lt $rh;$ly++){ for ($lx=0;$lx -lt $rw;$lx++) {
  $i=$ly*$rw+$lx
  if ($cls[$i] -eq 1) { $crop.SetPixel($lx,$ly,[System.Drawing.Color]::FromArgb(255,255,140,0)) }
  elseif ($reg[$i] -gt 0 -and -not $touchesEdge[$reg[$i]]) { $crop.SetPixel($lx,$ly,[System.Drawing.Color]::FromArgb(255,0,220,80)) }
}}
$z=14
$big = New-Object System.Drawing.Bitmap ($rw*$z),($rh*$z)
$gb=[System.Drawing.Graphics]::FromImage($big)
$gb.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$gb.DrawImage($crop,(New-Object System.Drawing.Rectangle 0,0,($rw*$z),($rh*$z)))
$gb.Dispose()
$big.Save((Join-Path $root "_trace_$name.png"),[System.Drawing.Imaging.ImageFormat]::Png)
$big.Dispose(); $crop.Dispose()

# emit dots file: line + enclosed-fill = feature DOTS; edge-touching fill excluded (jacket)
$lines2 = New-Object System.Collections.ArrayList
[void]$lines2.Add("# part: $name (traced via local X/B rim decomposition, px_trace_feature.ps1)")
[void]$lines2.Add("DOTS:")
for ($ly=0;$ly -lt $rh;$ly++) {
  $sb = New-Object System.Text.StringBuilder
  $runS=-1
  for ($lx=0;$lx -le $rw;$lx++) {
    $isP=$false
    if ($lx -lt $rw) { $i=$ly*$rw+$lx; $isP = ($cls[$i] -eq 1) -or ($reg[$i] -gt 0 -and -not $touchesEdge[$reg[$i]]) }
    if ($isP -and $runS -lt 0) { $runS=$lx }
    if (-not $isP -and $runS -ge 0) {
      $x0=$rx+$runS; $x1=$rx+$lx-1
      if ($x0 -eq $x1) { [void]$sb.Append(" $x0") } else { [void]$sb.Append(" $x0-$x1") }
      $runS=-1
    }
  }
  if ($sb.Length -gt 0) { [void]$lines2.Add("y=$($ry+$ly):$($sb.ToString())") }
}
$lines2 -join "`n" | Out-File (Join-Path $root "_trace_dots_$name.txt") -Encoding ascii
Write-Host "wrote _trace_$name.png and _trace_dots_$name.txt"

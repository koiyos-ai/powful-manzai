# px_regen_body.ps1 - regenerate body-part dot files from the outline-first regions.
# Fill dots: region -> part table (regions 1/2 split into sleeve/jacket via sane sleeve tokens).
# Flaps: kept from the redone _dots_flap_L/R.txt (their rims are X/B fill, not line-separable).
# Line dots: assigned by neighbor-part priority; sleeve/jacket contacts recorded as seam AMBIGUOUS.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$W=352; $H=192

# ---------- load region map ----------
$regionOf = New-Object int[] ($W*$H)   # >0 region id, -2 line, 0 none
foreach ($l in (Get-Content (Join-Path $root "_cc_map.txt") -Encoding UTF8)) {
  if ($l -match "^y=(\d+)(.*)$") {
    $y=[int]$Matches[1]; $rest=$Matches[2]
    foreach ($tok in ($rest.Trim() -split '\s+')) {
      if ($tok -match "^(\d+)-(\d+):L$") {
        for($x=[int]$Matches[1];$x -le [int]$Matches[2];$x++){ $regionOf[$y*$W+$x] = -2 }
      } elseif ($tok -match "^(\d+)-(\d+):(\d+)$") {
        $id=[int]$Matches[3]
        for($x=[int]$Matches[1];$x -le [int]$Matches[2];$x++){ $regionOf[$y*$W+$x] = $id }
      }
    }
  }
}

# ---------- region -> part table (hi-res black-outline mask, re-adjudicated 2026-07-17) ----------
# region 1 = whole jacket incl sleeves/lapels/flaps (their seams are dark-red creases,
# not black lines, even in the hi-res source) -> split by verified seed sets.
$r2p = New-Object 'System.Collections.Generic.Dictionary[int,string]'
$r2p[1]="SPLIT"
$r2p[2]="jacket_body"; $r2p[3]="jacket_body"
$r2p[4]="shirt_collar"; $r2p[6]="shirt_collar"; $r2p[7]="shirt_collar"
$r2p[5]="tie"; $r2p[8]="tie"
$r2p[9]="cuff_R"; $r2p[10]="cuff_L"
$r2p[11]="fist_L"; $r2p[12]="fist_R"
$r2p[13]="trousers"
foreach ($id in @(14,16,17,18,22,23,25,27,30,32,33,36)) { $r2p[$id]="shoe_L" }
foreach ($id in @(15,19,20,21,24,26,28,29,31,34,35,37,38)) { $r2p[$id]="shoe_R" }

# ---------- sane sleeve tokens from current files ----------
function LoadDots([string]$file,[int]$xmin,[int]$xmax,[int]$ymin,[int]$ymax) {
  $set = New-Object 'System.Collections.Generic.HashSet[int]'
  $p = Join-Path $root $file
  if (-not (Test-Path $p)) { return ,$set }
  foreach ($l in (Get-Content $p -Encoding UTF8)) {
    $t=$l.Trim()
    if ($t -match "^y=(\d+):\s*(.*)$") {
      $y=[int]$Matches[1]; $spec=$Matches[2]
      if ($y -lt $ymin -or $y -gt $ymax) { continue }
      $at=$spec.IndexOf('@'); if ($at -ge 0) { $spec=$spec.Substring(0,$at) }
      foreach ($tok in ($spec -split '\s+')) {
        $a=-1;$b=-1
        if ($tok -match "^(\d+)-(\d+)$") { $a=[int]$Matches[1]; $b=[int]$Matches[2] }
        elseif ($tok -match "^(\d+)$") { $a=[int]$Matches[1]; $b=$a }
        if ($a -lt 0) { continue }
        if ($a -lt $xmin -or $b -gt $xmax) { continue }   # sanity filter: whole token must fit zone
        for($x=$a;$x -le $b;$x++){ [void]$set.Add($y*$W+$x) }
      }
    }
  }
  return ,$set
}
# sleeve/body seam: MEASURED directly in the DOT ART master map (not hi-res - the first
# hi-res attempt drifted onto the outer silhouette by mistake, per user correction
# "輪郭線はあるのでは？ドット絵を再確認して" 2026-07-17). Per-row scan for dark-char runs
# (K/1/2/X///-/G/g) found a genuine SECOND cluster, separate from the silhouette run by a
# gap of red fill, running consistently from (155,114) to (151,134) - confirmed on both
# sides (right side mirrors at x_R=351-x_L, independently re-detected, matches within 1px).
$seamXbyY = @{
  106=154;107=154;108=154;109=154;110=154;111=154;112=154;113=154;
  114=155;115=154;116=154;117=154;118=154;119=154;120=154;121=154;
  122=153;123=153;124=153;125=153;126=152;127=152;128=152;129=152;
  130=152;131=152;132=151;133=151;134=151;
  135=151;136=151;137=150;138=147
  # y139+ : the seam cluster visibly fuses with the cuff/flap ink in the source art
  # (re-verified per-row; not stopped early this time) - past this point cuff_L/flap_L/
  # fist_L already own the relevant dots from their own independent traces, so no
  # extension is needed or meaningful.
}
$sleeveL = New-Object 'System.Collections.Generic.HashSet[int]'
$sleeveR = New-Object 'System.Collections.Generic.HashSet[int]'
foreach ($kv in $seamXbyY.GetEnumerator()) {
  $y=[int]$kv.Key; $xL=[int]$kv.Value; $xR=351-$xL
  for ($x=110;$x -lt $xL;$x++) { [void]$sleeveL.Add($y*$W+$x) }        # left of seam = sleeve
  for ($x=($xR+1);$x -le 240;$x++) { [void]$sleeveR.Add($y*$W+$x) }    # right of mirrored seam = sleeve
}
# flap/button: traced via local dark-shade blob flood-fill (px_trace_feature.ps1 -blob),
# NOT the earlier per-part rebuild (which under-traced the hook outline) or the original
# hardcoded rectangle (the failure the user flagged). See _trace_flapL/_trace_flapR/_trace_button.png.
$flapL   = LoadDots "_trace_dots_flapL.txt" 146 172 130 145
$flapR   = LoadDots "_trace_dots_flapR.txt" 179 206 130 145
$buttonT = LoadDots "_trace_dots_button.txt" 169 183 131 143
$lapelL  = LoadDots "_dots_lapel_L.txt" 150 178 100 132
$lapelR  = LoadDots "_dots_lapel_R.txt" 169 200 100 132
$shirtS  = LoadDots "_dots_shirt_collar.txt" 160 195 100 127
Write-Host ("sane tokens: sleeveL={0} sleeveR={1} flapL={2} flapR={3} lapelL={4} lapelR={5} shirt={6}" -f $sleeveL.Count,$sleeveR.Count,$flapL.Count,$flapR.Count,$lapelL.Count,$lapelR.Count,$shirtS.Count)

# ---------- assign fill dots ----------
$part = New-Object string[] ($W*$H)
for ($y=0;$y -lt $H;$y++) { for ($x=0;$x -lt $W;$x++) {
  $i=$y*$W+$x; $id=$regionOf[$i]
  if ($id -le 0) { continue }
  $p = $r2p[$id]
  if ($null -eq $p) { $p = "jacket_body" }   # unlisted fragment -> jacket (will show in report)
  if ($p -eq "SPLIT") {
    if ($buttonT.Contains($i)) { $p="button" }
    elseif ($flapL.Contains($i)) { $p="flap_L" }
    elseif ($flapR.Contains($i)) { $p="flap_R" }
    elseif ($sleeveL.Contains($i)) { $p="sleeve_L" }
    elseif ($sleeveR.Contains($i)) { $p="sleeve_R" }
    elseif ($lapelL.Contains($i)) { $p="lapel_L" }
    elseif ($lapelR.Contains($i)) { $p="lapel_R" }
    elseif ($shirtS.Contains($i)) { $p="shirt_collar" }
    else { $p="jacket_body" }
  }
  $part[$i] = $p
}}

# ---------- line-dot assignment: layer-synchronous BFS from FILL dots only ----------
# distance = layers from the nearest fill region; priority only breaks same-layer ties.
# (v1 allowed intra-layer chaining + global priority -> placket flooded down the whole
#  connected line network into trouser/shoe outlines. Fixed 2026-07-17.)
$prio = New-Object 'System.Collections.Generic.Dictionary[string,int]'
$order = @("button","placket","flap_L","flap_R","cuff_L","cuff_R","tie","shirt_collar","lapel_L","lapel_R","fist_L","fist_R","sleeve_L","sleeve_R","shoe_L","shoe_R","trousers","jacket_body")
for ($k=0;$k -lt $order.Count;$k++) { $prio[$order[$k]] = $k }
# SHARED-outline rule (user directive 2026-07-17): a boundary line dot that meets
# fills/line-fronts of MULTIPLE parts at its first BFS layer is SHARED by those parts
# (one line serves both parts; no winner). $shared[i] = extra parts beyond $part[i].
$shared = New-Object 'System.Collections.Generic.Dictionary[int,System.Collections.Generic.HashSet[string]]'
for ($iter=0;$iter -lt 16;$iter++) {
  $next = New-Object 'System.Collections.Generic.Dictionary[int,string]'
  $nextShared = New-Object 'System.Collections.Generic.Dictionary[int,System.Collections.Generic.HashSet[string]]'
  for ($y=0;$y -lt $H;$y++) { for ($x=0;$x -lt $W;$x++) {
    $i=$y*$W+$x
    if ($regionOf[$i] -ne -2 -or $null -ne $part[$i]) { continue }
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($d in @(@(-1,0),@(1,0),@(0,-1),@(0,1),@(-1,-1),@(1,-1),@(-1,1),@(1,1))) {
      $nx=$x+$d[0]; $ny=$y+$d[1]
      if ($nx -lt 0 -or $nx -ge $W -or $ny -lt 0 -or $ny -ge $H) { continue }
      $np = $part[$ny*$W+$nx]        # reads CURRENT layer only (not $next)
      if ($null -ne $np) { [void]$seen.Add($np) }
    }
    if ($seen.Count -gt 0) {
      $best=$null; $bestP=9999
      foreach ($p in $seen) { if ($prio[$p] -lt $bestP) { $bestP=$prio[$p]; $best=$p } }
      $next[$i]=$best
      if ($seen.Count -gt 1) {
        $rest = New-Object 'System.Collections.Generic.HashSet[string]'
        foreach ($p in $seen) { if ($p -ne $best) { [void]$rest.Add($p) } }
        $nextShared[$i]=$rest
      }
    }
  }}
  if ($next.Count -eq 0) { break }
  foreach ($kv in $next.GetEnumerator()) { $part[$kv.Key] = $kv.Value }
  foreach ($kv in $nextShared.GetEnumerator()) { $shared[$kv.Key] = $kv.Value }
}
# post-pass: any line dot directly touching FILL of another part is shared with it
for ($y=0;$y -lt $H;$y++) { for ($x=0;$x -lt $W;$x++) {
  $i=$y*$W+$x
  if ($regionOf[$i] -ne -2 -or $null -eq $part[$i]) { continue }
  foreach ($d in @(@(-1,0),@(1,0),@(0,-1),@(0,1))) {
    $nx=$x+$d[0]; $ny=$y+$d[1]
    if ($nx -lt 0 -or $nx -ge $W -or $ny -lt 0 -or $ny -ge $H) { continue }
    $j=$ny*$W+$nx
    if ($regionOf[$j] -gt 0 -and $null -ne $part[$j] -and $part[$j] -ne $part[$i]) {
      if (-not $shared.ContainsKey($i)) { $shared[$i] = New-Object 'System.Collections.Generic.HashSet[string]' }
      [void]$shared[$i].Add($part[$j])
    }
  }
}}

# ---------- forced geometric overrides AFTER BFS ----------
# these features are drawn as dark-red creases (not black outline) so they live in
# fill regions and/or line dots; override both kinds by measured coordinates.
# placket: front-opening seam x173-174, y128-150 (adjudicated from master read)
for ($y=128;$y -le 150;$y++) { foreach ($x in @(173,174)) {
  $i=$y*$W+$x; if ($regionOf[$i] -ne 0) { $part[$i]="placket"; $shared.Remove($i) | Out-Null }
}}
# button: traced dark-shade ring around the seed (px_trace_feature.ps1 -blob). It sits
# ON the placket seam, so overlap dots become a genuine SHARED boundary, not a winner-take-all.
foreach ($i in $buttonT) {
  if ($part[$i] -eq "placket") {
    if (-not $shared.ContainsKey($i)) { $shared[$i] = New-Object 'System.Collections.Generic.HashSet[string]' }
    [void]$shared[$i].Add("button")
  } else { $part[$i]="button"; $shared.Remove($i) | Out-Null }
}
# flap/sleeve/lapel line-class dots recorded in their verified files
foreach ($i in $flapL) { if ($regionOf[$i] -eq -2) { $part[$i]="flap_L"; $shared.Remove($i) | Out-Null } }
foreach ($i in $flapR) { if ($regionOf[$i] -eq -2) { $part[$i]="flap_R"; $shared.Remove($i) | Out-Null } }
foreach ($i in $lapelL) { if ($regionOf[$i] -eq -2 -and $null -eq $part[$i]) { $part[$i]="lapel_L" } }
foreach ($i in $lapelR) { if ($regionOf[$i] -eq -2 -and $null -eq $part[$i]) { $part[$i]="lapel_R" } }
# re-apply the fill-contact sharing pass so forced dots also share their boundaries
for ($y=0;$y -lt $H;$y++) { for ($x=0;$x -lt $W;$x++) {
  $i=$y*$W+$x
  if ($regionOf[$i] -ne -2 -or $null -eq $part[$i]) { continue }
  foreach ($d in @(@(-1,0),@(1,0),@(0,-1),@(0,1))) {
    $nx=$x+$d[0]; $ny=$y+$d[1]
    if ($nx -lt 0 -or $nx -ge $W -or $ny -lt 0 -or $ny -ge $H) { continue }
    $j=$ny*$W+$nx
    if ($regionOf[$j] -gt 0 -and $null -ne $part[$j] -and $part[$j] -ne $part[$i]) {
      if (-not $shared.ContainsKey($i)) { $shared[$i] = New-Object 'System.Collections.Generic.HashSet[string]' }
      [void]$shared[$i].Add($part[$j])
    }
  }
}}

# ---------- emit files (DOTS = exclusive; SHARED = boundary line shared with partners) ----------
$targets = @("sleeve_L","sleeve_R","jacket_body","lapel_L","lapel_R","shirt_collar","tie","placket","button","cuff_L","cuff_R","fist_L","fist_R","trousers","shoe_L","shoe_R","flap_L","flap_R")
foreach ($t in $targets) {
  $lines = New-Object System.Collections.ArrayList
  [void]$lines.Add("# part: $t")
  [void]$lines.Add("# generated by px_regen_body.ps1 (black-outline regions + shared-outline rule, 2026-07-17)")
  [void]$lines.Add("DOTS:")
  for ($y=0;$y -lt $H;$y++) {
    $sb = New-Object System.Text.StringBuilder
    $runS=-1
    for ($x=0;$x -le $W;$x++) {
      $isP = $false
      if ($x -lt $W) {
        $i=$y*$W+$x
        $isP = ($part[$i] -eq $t -and -not $shared.ContainsKey($i))
      }
      if ($isP -and $runS -lt 0) { $runS=$x }
      if (-not $isP -and $runS -ge 0) {
        if ($x-1 -eq $runS) { [void]$sb.Append(" $runS") } else { [void]$sb.Append(" $runS-$($x-1)") }
        $runS=-1
      }
    }
    if ($sb.Length -gt 0) { [void]$lines.Add("y=$y$($sb.ToString())".Replace("y=$y ","y=$y" + ": ")) }
  }
  # SHARED section: dot belongs to this file if it's the primary owner OR a partner
  $shRows = New-Object 'System.Collections.Generic.Dictionary[int,System.Collections.Generic.Dictionary[string,System.Collections.ArrayList]]'
  foreach ($kv in $shared.GetEnumerator()) {
    $i=$kv.Key
    $partners = New-Object System.Collections.ArrayList
    $mine = $false
    if ($part[$i] -eq $t) { $mine = $true; foreach ($q in $kv.Value) { [void]$partners.Add($q) } }
    elseif ($kv.Value.Contains($t)) {
      $mine = $true
      [void]$partners.Add($part[$i])
      foreach ($q in $kv.Value) { if ($q -ne $t) { [void]$partners.Add($q) } }
    }
    if (-not $mine) { continue }
    $y=[math]::Floor($i/$W); $x=$i%$W
    $pk = ($partners | Sort-Object) -join ","
    if (-not $shRows.ContainsKey($y)) { $shRows[$y] = New-Object 'System.Collections.Generic.Dictionary[string,System.Collections.ArrayList]' }
    if (-not $shRows[$y].ContainsKey($pk)) { $shRows[$y][$pk] = New-Object System.Collections.ArrayList }
    [void]$shRows[$y][$pk].Add($x)
  }
  if ($shRows.Count -gt 0) {
    [void]$lines.Add("SHARED:")
    foreach ($y in ($shRows.Keys | Sort-Object)) {
      foreach ($pk in $shRows[$y].Keys) {
        $xs = $shRows[$y][$pk] | Sort-Object
        # compress to runs
        $sb2 = New-Object System.Text.StringBuilder
        $runS=-1; $prev=-99
        foreach ($x in $xs) {
          if ($runS -lt 0) { $runS=$x }
          elseif ($x -ne $prev+1) {
            if ($prev -eq $runS) { [void]$sb2.Append(" $runS") } else { [void]$sb2.Append(" $runS-$prev") }
            $runS=$x
          }
          $prev=$x
        }
        if ($runS -ge 0) { if ($prev -eq $runS) { [void]$sb2.Append(" $runS") } else { [void]$sb2.Append(" $runS-$prev") } }
        [void]$lines.Add(("y={0}:{1} @shared-with:{2}" -f $y,$sb2.ToString(),$pk))
      }
    }
  }
  $lines -join "`n" | Out-File (Join-Path $root "_dots_$t.txt") -Encoding ascii
}
Write-Host "regenerated $($targets.Count) files (with SHARED outline sections)"

# leftover check: any body-zone dot with no part
$left=0
for ($i=0;$i -lt $W*$H;$i++) { if ($regionOf[$i] -ne 0 -and $null -eq $part[$i]) { $left++ } }
Write-Host "unassigned zone dots: $left"

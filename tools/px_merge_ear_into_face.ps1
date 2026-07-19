# px_merge_ear_into_face.ps1 - user directive 2026-07-18: merge ear_L/ear_R into face
# (face = all head skin including ears). Unions all dots from face.txt (DOTS+SHARED),
# ear_L.txt (DOTS+AMBIGUOUS), ear_R.txt (DOTS+AMBIGUOUS) into one face.txt DOTS section.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

function ParseAll([string]$file) {
  $dots = New-Object 'System.Collections.Generic.Dictionary[int,System.Collections.Generic.HashSet[int]]'
  foreach ($l in (Get-Content (Join-Path $root $file) -Encoding UTF8)) {
    $t = $l.Trim()
    if ($t -match "^y=(\d+):\s*(.*)$") {
      $y=[int]$Matches[1]; $spec=$Matches[2]
      $at=$spec.IndexOf('@'); if ($at -ge 0) { $spec=$spec.Substring(0,$at) }
      if (-not $dots.ContainsKey($y)) { $dots[$y] = New-Object 'System.Collections.Generic.HashSet[int]' }
      foreach ($tok in ($spec -split '\s+')) {
        if ($tok -match "^(\d+)-(\d+)$") { for($x=[int]$Matches[1];$x -le [int]$Matches[2];$x++){ [void]$dots[$y].Add($x) } }
        elseif ($tok -match "^(\d+)$") { [void]$dots[$y].Add([int]$Matches[1]) }
      }
    }
  }
  return $dots
}

$merged = New-Object 'System.Collections.Generic.Dictionary[int,System.Collections.Generic.HashSet[int]]'
foreach ($f in @("_dots_face.txt","_dots_ear_L.txt","_dots_ear_R.txt")) {
  $d = ParseAll $f
  foreach ($kv in $d.GetEnumerator()) {
    if (-not $merged.ContainsKey($kv.Key)) { $merged[$kv.Key] = New-Object 'System.Collections.Generic.HashSet[int]' }
    foreach ($x in $kv.Value) { [void]$merged[$kv.Key].Add($x) }
  }
}

$lines = New-Object System.Collections.ArrayList
[void]$lines.Add("# part: face (head skin, INCLUDING ears - merged 2026-07-18 per user directive)")
[void]$lines.Add("# ear_L/ear_R folded in: the soft ear<->cheek 'no outline' boundary made the")
[void]$lines.Add("# separate-ear split feel arbitrary; user approved unifying as one part.")
[void]$lines.Add("DOTS:")
foreach ($y in ($merged.Keys | Sort-Object)) {
  $xs = $merged[$y] | Sort-Object
  $sb = New-Object System.Text.StringBuilder
  $runS=-1; $prev=-99
  foreach ($x in $xs) {
    if ($runS -lt 0) { $runS=$x }
    elseif ($x -ne $prev+1) {
      if ($prev -eq $runS) { [void]$sb.Append(" $runS") } else { [void]$sb.Append(" $runS-$prev") }
      $runS=$x
    }
    $prev=$x
  }
  if ($runS -ge 0) { if ($prev -eq $runS) { [void]$sb.Append(" $runS") } else { [void]$sb.Append(" $runS-$prev") } }
  [void]$lines.Add("y=${y}:$($sb.ToString())")
}
$lines -join "`n" | Out-File (Join-Path $root "_dots_face.txt") -Encoding ascii

Remove-Item (Join-Path $root "_dots_ear_L.txt") -Force
Remove-Item (Join-Path $root "_dots_ear_R.txt") -Force
Write-Host "merged. face.txt rows: $($merged.Count). ear_L.txt/ear_R.txt removed."

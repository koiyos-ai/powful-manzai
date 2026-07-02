# Phase 1: generate an editable text pixel-map (under-drawing) from a master illustration.
# alpha-aware box downscale -> center in 64x96 -> snap to fixed palette -> 1px silhouette outline.
# ASCII only. Usage: powershell -File _underdraw.ps1 -char hero -master images\parts\hero_master.png
param(
  [string]$char = "hero",
  [string]$master = "",
  [int]$CW = 64,
  [int]$CH = 96,
  [int]$targetH = 92,
  [int]$topMargin = 2
)
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
. (Join-Path $root "tools\pxpalettes.ps1")
if(-not $PXPAL.ContainsKey($char)){ throw "unknown char '$char'" }
$P = $PXPAL[$char]

# palette arrays (skip transparent) for nearest match
$symK=@(); $symR=@(); $symG=@(); $symB=@()
foreach($k in $P.Keys){ if($k -eq '.'){continue}; $c=$P[$k]; $symK+=$k; $symR+=$c[0]; $symG+=$c[1]; $symB+=$c[2] }

function LoadBGRA($path){
  $bm = New-Object System.Drawing.Bitmap $path
  $w=$bm.Width; $h=$bm.Height
  $rect = New-Object System.Drawing.Rectangle 0,0,$w,$h
  $d = $bm.LockBits($rect,[System.Drawing.Imaging.ImageLockMode]::ReadOnly,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $bytes = New-Object byte[] ($d.Stride*$h)
  [System.Runtime.InteropServices.Marshal]::Copy($d.Scan0,$bytes,0,$bytes.Length)
  $bm.UnlockBits($d); $bm.Dispose()
  return @{B=$bytes;W=$w;H=$h;S=$d.Stride}
}
function ContentBBox($img){
  $w=$img.W;$h=$img.H;$s=$img.S;$b=$img.B
  $x0=$w;$y0=$h;$x1=-1;$y1=-1
  for($y=0;$y -lt $h;$y++){ $row=$y*$s
    for($x=0;$x -lt $w;$x++){ if($b[$row+$x*4+3] -gt 16){
      if($x -lt $x0){$x0=$x}; if($x -gt $x1){$x1=$x}; if($y -lt $y0){$y0=$y}; if($y -gt $y1){$y1=$y} } } }
  return @{X0=$x0;Y0=$y0;X1=$x1;Y1=$y1}
}
function Nearest($r,$g,$b){
  $bi=0;$bd=[double]::MaxValue
  for($i=0;$i -lt $symK.Count;$i++){ $dr=$r-$symR[$i];$dg=$g-$symG[$i];$db=$b-$symB[$i]; $d=$dr*$dr+$dg*$dg+$db*$db; if($d -lt $bd){$bd=$d;$bi=$i} }
  return $symK[$bi]
}

$mpath = $master
if($mpath -eq ""){ throw "master path required" }
if(-not [System.IO.Path]::IsPathRooted($mpath)){ $mpath = Join-Path $root $master }
$img = LoadBGRA $mpath
$bb = ContentBBox $img
$srcW=$bb.X1-$bb.X0+1; $srcH=$bb.Y1-$bb.Y0+1
$scale = $targetH/$srcH
$tw = [Math]::Max(1,[int][Math]::Round($srcW*$scale))
$th = $targetH
$s=$img.S; $b=$img.B

# init canvas grid with '.' (flat 1D array; index = y*CW + x)
$grid = New-Object 'char[]' ($CH*$CW)
for($i=0;$i -lt $grid.Length;$i++){ $grid[$i]=[char]'.' }
$xoff=[int][Math]::Floor(($CW-$tw)/2)
$yoff=$topMargin

for($ty=0;$ty -lt $th;$ty++){
  $sy0=$bb.Y0+[int][Math]::Floor($ty/$scale); $sy1=$bb.Y0+[int][Math]::Floor(($ty+1)/$scale)-1
  if($sy1 -lt $sy0){$sy1=$sy0}; if($sy1 -gt $bb.Y1){$sy1=$bb.Y1}
  for($tx=0;$tx -lt $tw;$tx++){
    $sx0=$bb.X0+[int][Math]::Floor($tx/$scale); $sx1=$bb.X0+[int][Math]::Floor(($tx+1)/$scale)-1
    if($sx1 -lt $sx0){$sx1=$sx0}; if($sx1 -gt $bb.X1){$sx1=$bb.X1}
    $sr=0;$sg=0;$sb=0;$op=0;$tot=0
    for($yy=$sy0;$yy -le $sy1;$yy++){ $row=$yy*$s
      for($xx=$sx0;$xx -le $sx1;$xx++){ $i=$row+$xx*4; $tot++
        if($b[$i+3] -gt 96){ $op++; $sb+=$b[$i]; $sg+=$b[$i+1]; $sr+=$b[$i+2] } } }
    $cy=$yoff+$ty; $cx=$xoff+$tx
    if($cy -ge 0 -and $cy -lt $CH -and $cx -ge 0 -and $cx -lt $CW){
      if($tot -gt 0 -and ($op/$tot) -ge 0.45 -and $op -gt 0){
        $sym = Nearest ([int]($sr/$op)) ([int]($sg/$op)) ([int]($sb/$op))
        $grid[$cy*$CW+$cx]=$sym
      }
    }
  }
}

# 1px silhouette outline: opaque cell touching a '.' (4-neighbor) becomes 'K'
$dot=[char]'.'
$src = New-Object 'char[]' ($CH*$CW)
for($i=0;$i -lt $grid.Length;$i++){ $src[$i]=$grid[$i] }
for($y=0;$y -lt $CH;$y++){ for($x=0;$x -lt $CW;$x++){
  $idx=$y*$CW+$x
  if($src[$idx] -ne $dot){
    $edge=$false
    if($y -eq 0 -or $src[$idx-$CW] -eq $dot){$edge=$true}
    if(-not $edge -and ($y -eq $CH-1 -or $src[$idx+$CW] -eq $dot)){$edge=$true}
    if(-not $edge -and ($x -eq 0 -or $src[$idx-1] -eq $dot)){$edge=$true}
    if(-not $edge -and ($x -eq $CW-1 -or $src[$idx+1] -eq $dot)){$edge=$true}
    if($edge){ $grid[$idx]=[char]'K' }
  }
}}

# write txt (note: avoid a var named $ch -- it aliases $CH, PS vars are case-insensitive)
$sb2 = New-Object System.Text.StringBuilder
for($y=0;$y -lt $CH;$y++){
  $rowchars = New-Object 'char[]' $CW
  for($x=0;$x -lt $CW;$x++){ $rowchars[$x]=$grid[$y*$CW+$x] }
  [void]$sb2.AppendLine((-join $rowchars))
}
$outTxt = Join-Path $root ("_pxmap_{0}.txt" -f $char)
[System.IO.File]::WriteAllText($outTxt,$sb2.ToString())
Write-Host ("wrote {0}  (canvas {1}x{2}, char {3}x{4} at xoff={5})" -f (Split-Path $outTxt -Leaf),$CW,$CH,$tw,$th,$xoff)

# px_rebuild_variant.ps1 - DB-enforced clean pose variant.
# For every dot:
#   base part in REPLACED set  -> take the variant's pixel (arm removal / reveal repaint)
#   base transparent           -> take the variant's pixel (the newly drawn raised arm)
#   otherwise                  -> take the BASE pixel (everything else preserved exactly)
# This guarantees zero out-of-scope changes by construction.
# Usage: -variant _pxv2_hero_handupR6.png -replaced "sleeve_R,cuff_R,fist_R" -out _pxv2_hero_up_R_final.png
param(
  [string]$variant,
  [string]$replaced,
  [string]$out
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$W=352; $H=192
$repSet = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($d in ($replaced -split ',')) { [void]$repSet.Add($d.Trim()) }

function LoadPx([string]$p) {
  $img = [System.Drawing.Bitmap]::FromFile((Join-Path $root $p))
  $rect = New-Object System.Drawing.Rectangle 0,0,$img.Width,$img.Height
  $bd = $img.LockBits($rect,[System.Drawing.Imaging.ImageLockMode]::ReadOnly,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $px = New-Object byte[] ($bd.Stride*$img.Height)
  [System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0,$px,0,$px.Length)
  $st=$bd.Stride; $img.UnlockBits($bd); $img.Dispose()
  return @($px,$st)
}
$b = LoadPx "_pxv2_hero_base.png"; $pxB=$b[0]; $stB=$b[1]
$v = LoadPx $variant;              $pxV=$v[0]; $stV=$v[1]

# dot -> owned-by-replaced-part? (a dot whose owners are ALL within replaced set, or shared
# dots owned partly by replaced parts: treat as replaced only if ANY owner is in the set AND
# no owner outside the set is a non-arm part... simpler and safer: replaced if ANY owner in set.
# Shared boundary dots (e.g. seam with jacket) then take the variant pixel - correct, since
# removing the arm removes its side of the shared line too; the variant repainted it.)
$isRep = New-Object bool[] ($W*$H)
foreach ($f in (Get-ChildItem (Join-Path $root "_dots_*.txt"))) {
  $part = $f.BaseName -replace '^_dots_',''
  if (-not $repSet.Contains($part)) { continue }
  foreach ($l in (Get-Content $f.FullName -Encoding UTF8)) {
    $t=$l.Trim()
    if ($t -match "^y=(\d+):\s*([^@]*)") {
      $y=[int]$Matches[1]
      foreach ($tok in ($Matches[2].Trim() -split '\s+')) {
        $a=-1;$b2=-1
        if ($tok -match "^(\d+)-(\d+)$") { $a=[int]$Matches[1]; $b2=[int]$Matches[2] }
        elseif ($tok -match "^(\d+)$") { $a=[int]$Matches[1]; $b2=$a }
        if ($a -lt 0) { continue }
        for ($x=$a;$x -le $b2;$x++) { $isRep[$y*352+$x]=$true }
      }
    }
  }
}

$dst = New-Object System.Drawing.Bitmap $W,$H,([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$bdD = $dst.LockBits((New-Object System.Drawing.Rectangle 0,0,$W,$H),[System.Drawing.Imaging.ImageLockMode]::WriteOnly,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$pxD = New-Object byte[] ($bdD.Stride*$H)
$fromV=0; $fromB=0; $newDots=0
for ($y=0;$y -lt $H;$y++) { for ($x=0;$x -lt $W;$x++) {
  $i=$y*352+$x
  $oB=$y*$stB+$x*4; $oV=$y*$stV+$x*4; $oD=$y*$bdD.Stride+$x*4
  $baseOpq = ($pxB[$oB+3] -ge 128)
  $useV = $false
  if ($baseOpq -and $isRep[$i]) { $useV = $true; $fromV++ }
  elseif (-not $baseOpq) { $useV = $true; if ($pxV[$oV+3] -ge 128) { $newDots++ } }
  else { $fromB++ }
  if ($useV) { $pxD[$oD]=$pxV[$oV]; $pxD[$oD+1]=$pxV[$oV+1]; $pxD[$oD+2]=$pxV[$oV+2]; $pxD[$oD+3]=$pxV[$oV+3] }
  else       { $pxD[$oD]=$pxB[$oB]; $pxD[$oD+1]=$pxB[$oB+1]; $pxD[$oD+2]=$pxB[$oB+2]; $pxD[$oD+3]=$pxB[$oB+3] }
}}
[System.Runtime.InteropServices.Marshal]::Copy($pxD,0,$bdD.Scan0,$pxD.Length)
$dst.UnlockBits($bdD)
$dst.Save((Join-Path $root $out),[System.Drawing.Imaging.ImageFormat]::Png)

$big = New-Object System.Drawing.Bitmap ($W*4),($H*4)
$g2=[System.Drawing.Graphics]::FromImage($big)
$g2.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g2.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::Half
$g2.DrawImage($dst,(New-Object System.Drawing.Rectangle 0,0,($W*4),($H*4)))
$g2.Dispose()
$big.Save((Join-Path $root ($out -replace '\.png$','_big.png')),[System.Drawing.Imaging.ImageFormat]::Png)
$big.Dispose(); $dst.Dispose()
Write-Host ("wrote {0}: replaced-part dots from variant={1}, new drawing dots={2}, base-preserved dots={3}" -f $out,$fromV,$newDots,$fromB)

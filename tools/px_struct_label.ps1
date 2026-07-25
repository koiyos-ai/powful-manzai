# px_struct_label.ps1 - Level-1 of the structure model: semantic label grid.
# Assigns every opaque pixel of _pxv2_hero_base.png a part label (annotation, not drawing).
# Arm/jacket separation uses the ingested torso layer (_pxv2_hero_torso.png) as clothes truth.
# Outputs: _pxlabel_hero.txt (legend+grid), _pxlabel_hero_overlay.png (4x color-coded), counts.
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot

function LoadPx([string]$p) {
  $img = [System.Drawing.Bitmap]::FromFile((Join-Path $root $p))
  $rect = New-Object System.Drawing.Rectangle 0,0,$img.Width,$img.Height
  $bd = $img.LockBits($rect,[System.Drawing.Imaging.ImageLockMode]::ReadOnly,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $px = New-Object byte[] ($bd.Stride*$img.Height)
  [System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0,$px,0,$px.Length)
  $st=$bd.Stride; $img.UnlockBits($bd); $img.Dispose()
  return @($px,$st)
}
$W=352; $H=192
$base = LoadPx "_pxv2_hero_base.png"
$torso = LoadPx "_pxv2_hero_torso.png"
$pxB=$base[0]; $stB=$base[1]
$pxT=$torso[0]; $stT=$torso[1]

# --- color family classifiers ---
function Fam([int]$r,[int]$g,[int]$b) {
  if ($r -ge 200 -and $g -ge 200 -and $b -ge 200) { return "white" }
  if ($r -ge 180 -and $g -ge 180 -and $b -ge 200) { return "lav" }        # 200,200,232 etc
  if ($r -ge 200 -and $g -ge 180 -and $b -lt 120) { return "yellow" }
  if ($r -ge 200 -and $g -ge 120 -and $b -ge 90)  { return "skin" }       # 248,200,168 / 248,152,120...
  if ($r -ge 200 -and $g -ge 100 -and $b -ge 90)  { return "skin" }
  if ($r -ge 216 -and $g -ge 140)                 { return "skin" }
  if ($r -ge 140 -and $g -lt 80 -and $b -lt 80)   { return "red" }        # 152..248 reds
  if ($r -ge 60 -and $r -le 130 -and $g -ge 20 -and $g -le 90 -and $b -le 70 -and $r -gt $g) { return "brown" } # 88,40,24 / shoe browns
  if ($r -lt 140 -and $g -lt 140 -and $b -lt 140) {
    if ($r -le 60 -and $g -le 40 -and $b -le 40 -and $r -gt ($g+10)) { return "darkred" }  # 40,8,8 / 56,24,24
    return "dark"                                                          # hair/outline/gray
  }
  return "other"
}

$label = New-Object char[] ($W*$H)
for ($i=0;$i -lt $W*$H;$i++) { $label[$i]='.' }

# hem bottom boundary (jacket vs trousers) per x - measured from grids:
# center dips to ~y152, sides reach ~y166
function HemY([int]$x) {
  if ($x -lt 150) { return 166 }
  if ($x -lt 158) { return 162 }
  if ($x -lt 166) { return 156 }
  if ($x -lt 196) { return 153 }
  if ($x -lt 206) { return 160 }
  return 166
}

for ($y=0;$y -lt $H;$y++) {
  for ($x=0;$x -lt $W;$x++) {
    $o=$y*$stB+$x*4
    if ($pxB[$o+3] -lt 128) { continue }
    $r=[int]$pxB[$o+2]; $g=[int]$pxB[$o+1]; $b=[int]$pxB[$o]
    $fam = Fam $r $g $b
    $oT=$y*$stT+$x*4
    $torsoOpaque = ($pxT[$oT+3] -ge 128)
    $c = '?'

    # ---------- head zone ----------
    if ($y -le 103) {
      if ($fam -eq "yellow") { $c='T' }
      elseif ($y -ge 101 -and $fam -eq "skin" -and $x -ge 166 -and $x -le 196) { $c='N' }   # neck under chin
      elseif ($fam -eq "skin" -or $fam -eq "white" -or $fam -eq "lav") {
        if ($y -ge 56 -and $y -le 92 -and $x -le 146) { $c='Y' }        # left ear
        elseif ($y -ge 56 -and $y -le 92 -and $x -ge 206) { $c='Y' }    # right ear
        elseif (($fam -eq "white" -or $fam -eq "lav") -and $y -ge 66 -and $y -le 88 -and $x -ge 152 -and $x -le 202) { $c='E' } # eye whites
        else { $c='F' }
      }
      else { # dark families in head zone
        if ($y -ge 55 -and $y -le 66 -and $x -ge 154 -and $x -le 199) { $c='B' }   # brows band
        elseif ($y -ge 67 -and $y -le 90 -and $x -ge 154 -and $x -le 200) { $c='E' } # eyes
        elseif ($y -ge 56 -and $y -le 92 -and ($x -le 146 -or $x -ge 206) -and ($fam -eq "dark" -or $fam -eq "darkred" -or $fam -eq "brown")) {
          # dark inside ear zone: ear outline/canal -> ear
          if ($x -le 132 -or $x -ge 220) { $c='H' } else { $c='Y' }
        }
        else { $c='H' }
      }
    }
    # ---------- below head ----------
    else {
      # shoes / trousers zone first
      if ($y -ge 164 -and ($fam -eq "brown" -or ($y -ge 168 -and ($fam -eq "dark" -or $fam -eq "darkred" -or $fam -eq "white" -or $fam -eq "lav")))) {
        if ($x -lt 176) { $c='s' } else { $c='S' }
      }
      elseif ($y -gt (HemY $x)) {
        if ($fam -eq "brown" -or ($y -ge 168)) { if ($x -lt 176) { $c='s' } else { $c='S' } }
        else { $c='t' }
      }
      elseif ($fam -eq "yellow") { $c='T' }
      else {
        # arm zones: left x<=158, right x>=196 (between y104-166)
        $isArmZone = $false
        if ($y -ge 104 -and $y -le 166) {
          if ($x -le 158) {
            if (-not $torsoOpaque) { $isArmZone = $true }
            else {
              # over jacket: differs from torso layer => arm pixel
              $dr=[math]::Abs($r-[int]$pxT[$oT+2])+[math]::Abs($g-[int]$pxT[$oT+1])+[math]::Abs($b-[int]$pxT[$oT])
              if ($dr -ge 48) { $isArmZone = $true }
            }
          } elseif ($x -ge 194) {
            if (-not $torsoOpaque) { $isArmZone = $true }
            else {
              $dr=[math]::Abs($r-[int]$pxT[$oT+2])+[math]::Abs($g-[int]$pxT[$oT+1])+[math]::Abs($b-[int]$pxT[$oT])
              if ($dr -ge 48) { $isArmZone = $true }
            }
          }
        }
        if ($isArmZone) {
          if ($fam -eq "skin") { if ($x -lt 176) { $c='m' } else { $c='M' } }
          elseif ($fam -eq "white" -or $fam -eq "lav") { if ($x -lt 176) { $c='u' } else { $c='U' } }
          else { if ($x -lt 176) { $c='a' } else { $c='A' } }
        }
        elseif ($fam -eq "skin" -and $y -le 110) { $c='N' }
        elseif (($fam -eq "white" -or $fam -eq "lav") -and $y -le 126 -and $x -ge 162 -and $x -le 198) { $c='W' }  # shirt collar
        elseif (($fam -eq "white" -or $fam -eq "lav") -and $y -ge 127 -and $y -le 148) {
          # stray cuff whites just outside arm zone
          if ($x -lt 176) { $c='u' } else { $c='U' }
        }
        else {
          # jacket interior: lapels / placket / button / flaps / body
          # button: dark ring at (180..187, 129..137)
          if ($x -ge 179 -and $x -le 188 -and $y -ge 128 -and $y -le 138 -and ($fam -eq "dark" -or $fam -eq "darkred" -or $fam -eq "brown")) { $c='O' }
          # placket: front-opening crease column below V bottom
          elseif ($x -ge 180 -and $x -le 188 -and $y -ge 124 -and $y -le 148 -and ($fam -eq "dark" -or $fam -eq "darkred" -or $fam -eq "brown")) { $c='P' }
          # flaps: hip bands (tightened to the visible flap outlines)
          elseif ($y -ge 140 -and $y -le 149 -and $x -ge 151 -and $x -le 171) { $c='f' }
          elseif ($y -ge 140 -and $y -le 149 -and $x -ge 185 -and $x -le 204) { $c='g' }
          # lapels: bands along the V edges (measured from _grid_center / collar crops)
          # left V edge x = 164 + 0.75*(y-104); lapel = 9px band left of it
          elseif ($y -ge 101 -and $y -le 128 -and $x -le (164 + [int](($y-104)*0.75)) -and $x -ge (164 + [int](($y-104)*0.75)) - 9) { $c='l' }
          # right V edge x = 186 - 0.12*(y-104); lapel = 10px band right of it
          elseif ($y -ge 101 -and $y -le 128 -and $x -ge (186 - [int](($y-104)*0.12)) -and $x -le (186 - [int](($y-104)*0.12)) + 10) { $c='L' }
          else { $c='J' }
        }
      }
    }
    $label[$y*$W+$x] = $c
  }
}

# ---------- post-pass: unresolved '?' none; smooth isolated labels (optional skip) ----------

# counts (case-sensitive dictionary - PS hashtables merge 'l'/'L')
$counts = New-Object 'System.Collections.Generic.Dictionary[string,int]'
foreach ($ch in $label) {
  if ($ch -eq '.') { continue }
  $k=[string]$ch
  if ($counts.ContainsKey($k)) { $counts[$k]++ } else { $counts[$k]=1 }
}
Write-Host "label counts:"
foreach ($k in ($counts.Keys | Sort-Object)) { Write-Host ("  {0} = {1}" -f $k, $counts[$k]) }

# ---------- write label grid ----------
$lines = New-Object System.Collections.ArrayList
[void]$lines.Add("# _pxlabel_hero.txt - semantic label grid for _pxv2_hero_base.png (352x192)")
[void]$lines.Add("# LEGEND: .=transparent H=hair F=face Y=ear B=brow E=eye N=neck W=shirtcollar T=tie")
[void]$lines.Add("#   l=lapelL L=lapelR J=jacketbody P=placket O=button f=flapL g=flapR")
[void]$lines.Add("#   a=sleeveL A=sleeveR u=cuffL U=cuffR m=fistL M=fistR t=trousers s=shoeL S=shoeR")
[void]$lines.Add("GRID:")
for ($y=0;$y -lt $H;$y++) {
  $row = New-Object System.Text.StringBuilder
  for ($x=0;$x -lt $W;$x++) { [void]$row.Append($label[$y*$W+$x]) }
  [void]$lines.Add($row.ToString())
}
$lines -join "`n" | Out-File -FilePath (Join-Path $root "_pxlabel_hero.txt") -Encoding ascii

# ---------- overlay ----------
$colors = New-Object 'System.Collections.Generic.Dictionary[string,int[]]'
$colors['H']=@(64,64,64);    $colors['F']=@(248,200,160); $colors['Y']=@(240,144,72);  $colors['B']=@(48,96,192)
$colors['E']=@(0,192,224);   $colors['N']=@(192,144,112); $colors['W']=@(255,255,255); $colors['T']=@(248,216,40)
$colors['l']=@(255,0,255);   $colors['L']=@(255,128,192); $colors['J']=@(192,0,24);    $colors['P']=@(0,128,255)
$colors['O']=@(0,255,0);     $colors['f']=@(0,160,128);   $colors['g']=@(128,160,0);   $colors['a']=@(128,0,255)
$colors['A']=@(176,96,255);  $colors['u']=@(96,192,255);  $colors['U']=@(160,224,255); $colors['m']=@(248,224,176)
$colors['M']=@(232,208,144); $colors['t']=@(112,16,16);   $colors['s']=@(128,64,16);   $colors['S']=@(160,96,32)
$dst = New-Object System.Drawing.Bitmap $W,$H,([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$rect = New-Object System.Drawing.Rectangle 0,0,$W,$H
$bdD = $dst.LockBits($rect,[System.Drawing.Imaging.ImageLockMode]::WriteOnly,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$pxD = New-Object byte[] ($bdD.Stride*$H)
for ($y=0;$y -lt $H;$y++) { for ($x=0;$x -lt $W;$x++) {
  $ch = $label[$y*$W+$x]
  if ($ch -eq '.') { continue }
  $col = $colors[[string]$ch]
  $oD=$y*$bdD.Stride+$x*4
  $pxD[$oD]=[byte]$col[2]; $pxD[$oD+1]=[byte]$col[1]; $pxD[$oD+2]=[byte]$col[0]; $pxD[$oD+3]=255
}}
[System.Runtime.InteropServices.Marshal]::Copy($pxD,0,$bdD.Scan0,$pxD.Length)
$dst.UnlockBits($bdD)
$big = New-Object System.Drawing.Bitmap ($W*4),($H*4)
$g2=[System.Drawing.Graphics]::FromImage($big)
$g2.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g2.DrawImage($dst,(New-Object System.Drawing.Rectangle 0,0,($W*4),($H*4)))
$g2.Dispose()
$big.Save((Join-Path $root "_pxlabel_hero_overlay.png"),[System.Drawing.Imaging.ImageFormat]::Png)
$big.Dispose(); $dst.Dispose()
Write-Host "done: _pxlabel_hero.txt + _pxlabel_hero_overlay.png"

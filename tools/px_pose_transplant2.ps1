# px_pose_transplant2.ps1 - Transplant pose from hero to yada with explicit color remap.
# Changed pixels from hero pose are remapped using a manual table (hero pxv2 colors -> yada palette).
param(
  [string]$heroBase = "images\px\hero_base.png",
  [string]$heroPose = "images\px\hero_upL.png",
  [string]$targetBase = "images\px\yada_base.png",
  [string]$out = "_pxv2_yada_upL.png"
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root $heroBase))) { $root = (Get-Location).Path }

# Explicit remap: hero pxv2 actual RGB -> yada palette RGB
# Red suit -> Blue suit, dark reds -> blue shadow, outlines -> K, etc.
$remap = @{
  # Red suit variants -> Blue suit B(19,66,160)
  "232,8,24"   = @(19,66,160)
  "216,24,24"  = @(19,66,160)
  "248,8,24"   = @(19,66,160)
  "232,8,8"    = @(19,66,160)
  "248,24,24"  = @(19,66,160)
  # Red shadow variants -> Blue shadow 4(14,44,112)
  "184,8,8"    = @(14,44,112)
  "168,8,8"    = @(14,44,112)
  "152,8,8"    = @(14,44,112)
  # Outline/dark -> K(28,24,30)
  "8,8,8"      = @(28,24,30)
  "56,24,24"   = @(28,24,30)
  "40,8,8"     = @(28,24,30)
  "24,8,8"     = @(28,24,30)
  "40,24,8"    = @(28,24,30)
  "56,8,8"     = @(28,24,30)
  # Skin -> S(254,216,175)
  "248,200,168"= @(254,216,175)
  "248,216,184"= @(254,216,175)
  "248,200,152"= @(254,216,175)
  # Skin shadow -> 1(224,175,133)
  "216,168,120"= @(224,175,133)
  "200,152,104"= @(224,175,133)
  "88,40,24"   = @(224,175,133)
  # White -> W(240,238,232)
  "248,248,248"= @(240,238,232)
  "248,248,232"= @(240,238,232)
  # Shirt shadow -> 9(200,201,208)
  "200,200,232"= @(200,201,208)
  "200,200,216"= @(200,201,208)
  # Hair -> H(34,31,33)
  "40,40,40"   = @(34,31,33)
  "56,56,56"   = @(34,31,33)
  # Tie -> T(240,197,35)
  "248,216,24" = @(240,197,35)
  # Cheek -> C(246,150,148)
  "248,152,120"= @(246,150,148)
  # Shoe -> 5(112,58,38)
  "120,56,24"  = @(112,58,38)
}

# Yada palette for fallback nearest-color matching
. (Join-Path $root "tools\pxpalettes.ps1")
$dstPal = $PXPAL["yada"]
$dPalR = New-Object System.Collections.ArrayList
$dPalG = New-Object System.Collections.ArrayList
$dPalB = New-Object System.Collections.ArrayList
foreach($k in $dstPal.Keys){ $v=$dstPal[$k]; if($v[3] -eq 0){continue}; [void]$dPalR.Add($v[0]); [void]$dPalG.Add($v[1]); [void]$dPalB.Add($v[2]) }

function LoadBmp([string]$path) {
  $o = [System.Drawing.Bitmap]::FromFile($path)
  $b = New-Object System.Drawing.Bitmap $o.Width,$o.Height,([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($b); $g.DrawImage($o,0,0,$o.Width,$o.Height); $g.Dispose(); $o.Dispose()
  return $b
}
function GetBytes([System.Drawing.Bitmap]$bmp) {
  $r = New-Object System.Drawing.Rectangle 0,0,$bmp.Width,$bmp.Height
  $d = $bmp.LockBits($r,[System.Drawing.Imaging.ImageLockMode]::ReadOnly,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $arr = New-Object byte[] ($d.Stride*$bmp.Height)
  [System.Runtime.InteropServices.Marshal]::Copy($d.Scan0,$arr,0,$arr.Length)
  $bmp.UnlockBits($d)
  return @{ bytes=$arr; stride=$d.Stride; w=$bmp.Width; h=$bmp.Height }
}

$hbBmp = LoadBmp (Join-Path $root $heroBase); $hb = GetBytes $hbBmp; $hbBmp.Dispose()
$hpBmp = LoadBmp (Join-Path $root $heroPose); $hp = GetBytes $hpBmp; $hpBmp.Dispose()
$tbBmp = LoadBmp (Join-Path $root $targetBase); $tb = GetBytes $tbBmp; $tbBmp.Dispose()

$ww=$hb.w; $hh=$hb.h; $stride=$hb.stride
$outBytes = New-Object byte[] $tb.bytes.Length
[Array]::Copy($tb.bytes, $outBytes, $tb.bytes.Length)

$kept=0; $exact=0; $nearest=0; $transp=0; $miss=@{}
for($y=0;$y -lt $hh;$y++){for($x=0;$x -lt $ww;$x++){
  $o=$y*$stride+$x*4
  $hbA=$hb.bytes[$o+3]; $hpA=$hp.bytes[$o+3]
  $hbR=$hb.bytes[$o+2]; $hbG=$hb.bytes[$o+1]; $hbB=$hb.bytes[$o]
  $hpR=$hp.bytes[$o+2]; $hpG=$hp.bytes[$o+1]; $hpB=$hp.bytes[$o]
  if($hbR -eq $hpR -and $hbG -eq $hpG -and $hbB -eq $hpB -and $hbA -eq $hpA){$kept++;continue}
  if($hpA -lt 128){$outBytes[$o]=0;$outBytes[$o+1]=0;$outBytes[$o+2]=0;$outBytes[$o+3]=0;$transp++;continue}
  $key="$hpR,$hpG,$hpB"
  if($remap.ContainsKey($key)){
    $c=$remap[$key]; $outBytes[$o]=$c[2]; $outBytes[$o+1]=$c[1]; $outBytes[$o+2]=$c[0]; $outBytes[$o+3]=255; $exact++
  } else {
    $bestD=[int]::MaxValue; $bR=0;$bG=0;$bB2=0
    for($j=0;$j -lt $dPalR.Count;$j++){
      $dr=$hpR-$dPalR[$j];$dg=$hpG-$dPalG[$j];$db=$hpB-$dPalB[$j]
      $d=$dr*$dr+$dg*$dg+$db*$db
      if($d -lt $bestD){$bestD=$d;$bR=$dPalR[$j];$bG=$dPalG[$j];$bB2=$dPalB[$j]}
    }
    $outBytes[$o]=$bB2;$outBytes[$o+1]=$bG;$outBytes[$o+2]=$bR;$outBytes[$o+3]=255;$nearest++
    if(-not $miss.ContainsKey($key)){$miss[$key]=0}; $miss[$key]++
  }
}}
Write-Host "kept=$kept exact=$exact nearest=$nearest transp=$transp"
if($miss.Count -gt 0){ Write-Host "unmapped colors:"; $miss.GetEnumerator()|Sort-Object -Property Value -Descending|ForEach-Object{ Write-Host ("  {0,4}x rgb({1})" -f $_.Value,$_.Key) }}

$dst = New-Object System.Drawing.Bitmap $ww,$hh,([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$bd = $dst.LockBits((New-Object System.Drawing.Rectangle 0,0,$ww,$hh),[System.Drawing.Imaging.ImageLockMode]::WriteOnly,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
[System.Runtime.InteropServices.Marshal]::Copy($outBytes,0,$bd.Scan0,$outBytes.Length)
$dst.UnlockBits($bd)
$dst.Save((Join-Path $root $out),[System.Drawing.Imaging.ImageFormat]::Png)
$big = New-Object System.Drawing.Bitmap ($ww*4),($hh*4)
$g2 = [System.Drawing.Graphics]::FromImage($big)
$g2.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g2.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::Half
$g2.DrawImage($dst,(New-Object System.Drawing.Rectangle 0,0,($ww*4),($hh*4)))
$g2.Dispose()
$big.Save((Join-Path $root ($out -replace "\.png$","_big.png")),[System.Drawing.Imaging.ImageFormat]::Png)
$big.Dispose();$dst.Dispose()
Write-Host "wrote $out"

# px_export_game.ps1 - export the finalized dot sprites as game assets.
# All three poses are cropped with the SAME box (x120-231, full height) so that
# swapping pose images in-game never shifts the character.
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root "images\px"
New-Item -ItemType Directory -Force $outDir | Out-Null

$cropX=120; $cropW=112; $cropY=0; $cropH=192
$jobs = @(
  @("_pxv2_hero_base.png",      "hero_base.png"),
  @("_pxv2_hero_up_L_final.png","hero_upL.png"),
  @("_pxv2_hero_up_R_final.png","hero_upR.png")
)
foreach ($j in $jobs) {
  $src = [System.Drawing.Bitmap]::FromFile((Join-Path $root $j[0]))
  $dst = New-Object System.Drawing.Bitmap $cropW,$cropH,([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($dst)
  $g.DrawImage($src,(New-Object System.Drawing.Rectangle 0,0,$cropW,$cropH),(New-Object System.Drawing.Rectangle $cropX,$cropY,$cropW,$cropH),[System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose(); $src.Dispose()
  $dst.Save((Join-Path $outDir $j[1]),[System.Drawing.Imaging.ImageFormat]::Png)
  $dst.Dispose()
  Write-Host ("exported {0} -> images/px/{1} ({2}x{3})" -f $j[0],$j[1],$cropW,$cropH)
}

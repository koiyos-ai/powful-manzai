# px_master.ps1 - canonical per-dot master map of a pxv2 sprite.
# Every dot (cell) of the 352x192 canvas is recorded as one char with a FIXED,
# collision-free palette code. Errors out on unknown colors (no silent guessing).
# Usage: powershell -ExecutionPolicy Bypass -File tools\px_master.ps1 -src _pxv2_hero_base.png -out _pxmaster_hero.txt
param(
  [string]$src = "_pxv2_hero_base.png",
  [string]$out = "_pxmaster_hero.txt"
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot

# canonical color codes (stable across all master maps)
$canon = @(
  @("K",8,8,8),      @("1",24,24,24),   @("G",56,56,56),   @("g",120,120,120),
  @("-",40,40,40),   @("2",24,8,8),     @("/",40,8,8),     @("X",56,24,24),
  @("B",88,40,24),   @("S",248,200,168),@("8",248,216,184),@("A",232,152,120),
  @("s",248,152,120),@("0",248,168,120),@("W",248,248,248),@("w",216,232,248),
  @("3",248,248,216),@("U",200,200,232),@("u",216,200,232),@("E",248,8,24),
  @("4",248,8,8),    @("R",232,8,24),   @("6",232,8,8),    @("e",232,24,24),
  @("D",216,24,24),  @("r",184,8,8),    @("d",168,8,8),    @("Y",248,216,40)
)
$map = New-Object 'System.Collections.Generic.Dictionary[int,string]'
foreach ($c in $canon) { $map[([int]$c[1] -shl 16) -bor ([int]$c[2] -shl 8) -bor [int]$c[3]] = [string]$c[0] }

$img = [System.Drawing.Bitmap]::FromFile((Join-Path $root $src))
$W=$img.Width; $H=$img.Height
$rect = New-Object System.Drawing.Rectangle 0,0,$W,$H
$bd = $img.LockBits($rect,[System.Drawing.Imaging.ImageLockMode]::ReadOnly,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$px = New-Object byte[] ($bd.Stride*$H)
[System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0,$px,0,$px.Length)
$st=$bd.Stride; $img.UnlockBits($bd); $img.Dispose()

$counts = New-Object 'System.Collections.Generic.Dictionary[string,int]'
$unknown = New-Object System.Collections.ArrayList
$rows = New-Object System.Collections.ArrayList
$nOpaque = 0
for ($y=0;$y -lt $H;$y++) {
  $sb = New-Object System.Text.StringBuilder
  for ($x=0;$x -lt $W;$x++) {
    $o=$y*$st+$x*4
    if ($px[$o+3] -lt 128) { [void]$sb.Append('.'); continue }
    $key = ([int]$px[$o+2] -shl 16) -bor ([int]$px[$o+1] -shl 8) -bor [int]$px[$o]
    if (-not $map.ContainsKey($key)) {
      [void]$unknown.Add("($x,$y) rgb($($px[$o+2]),$($px[$o+1]),$($px[$o]))")
      [void]$sb.Append('?'); continue
    }
    $ch = $map[$key]
    [void]$sb.Append($ch)
    if ($counts.ContainsKey($ch)) { $counts[$ch]++ } else { $counts[$ch]=1 }
    $nOpaque++
  }
  [void]$rows.Add($sb.ToString())
}
if ($unknown.Count -gt 0) {
  Write-Host "ERROR: unknown colors:"
  $unknown | Select-Object -First 20 | ForEach-Object { Write-Host "  $_" }
  exit 1
}

$lines = New-Object System.Collections.ArrayList
[void]$lines.Add("# canonical per-dot master map  src=$src  canvas=${W}x${H}")
[void]$lines.Add("# coordinates: columns x=0..$($W-1) (left->right), rows y=0..$($H-1) (top->bottom)")
[void]$lines.Add("# grid line N (after 'GRID:') = row y=N-1... precisely: first grid line = y0")
[void]$lines.Add("PALETTE:")
[void]$lines.Add(". = transparent")
foreach ($c in $canon) {
  $ch=[string]$c[0]
  $n = 0; if ($counts.ContainsKey($ch)) { $n = $counts[$ch] }
  [void]$lines.Add(("{0} = rgb({1},{2},{3}) x{4}" -f $ch,$c[1],$c[2],$c[3],$n))
}
[void]$lines.Add("GRID:")
foreach ($r in $rows) { [void]$lines.Add($r) }
$lines -join "`n" | Out-File -FilePath (Join-Path $root $out) -Encoding ascii
Write-Host "wrote $out ($nOpaque opaque dots, $($counts.Count) colors, canvas ${W}x${H})"

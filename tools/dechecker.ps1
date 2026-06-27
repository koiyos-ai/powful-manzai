# Convert a baked-in checkerboard "fake transparency" PNG into real alpha.
# Background = light near-gray checker pixels connected to the image border.
# Interior light highlights (surrounded by character) are preserved.
# usage: powershell -File tools\dechecker.ps1 <in.png> <out.png>
param([string]$inPath, [string]$outPath)
Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @"
using System;
public class DeChecker {
  // bg = near-gray (max-min<grayTol) AND bright (avg>brightMin), flood-connected to border.
  public static int Strip(byte[] b, int w, int h, int stride, int grayTol, int brightMin) {
    int n = w * h;
    bool[] isBg = new bool[n];
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        int i = y * stride + x * 4;
        int bl = b[i], g = b[i+1], r = b[i+2];
        int mx = Math.Max(r, Math.Max(g, bl)), mn = Math.Min(r, Math.Min(g, bl));
        int avg = (r + g + bl) / 3;
        if ((mx - mn) <= grayTol && avg >= brightMin) isBg[y*w+x] = true;
      }
    }
    bool[] bg = new bool[n];
    int[] stack = new int[n]; int sp = 0;
    Action<int,int> seed = (x,y) => { int p=y*w+x; if (isBg[p] && !bg[p]) { bg[p]=true; stack[sp++]=p; } };
    for (int x=0;x<w;x++){ seed(x,0); seed(x,h-1); }
    for (int y=0;y<h;y++){ seed(0,y); seed(w-1,y); }
    while (sp > 0) {
      int p = stack[--sp]; int y = p/w; int x = p-y*w;
      if (x>0   && isBg[p-1] && !bg[p-1]) { bg[p-1]=true; stack[sp++]=p-1; }
      if (x<w-1 && isBg[p+1] && !bg[p+1]) { bg[p+1]=true; stack[sp++]=p+1; }
      if (y>0   && isBg[p-w] && !bg[p-w]) { bg[p-w]=true; stack[sp++]=p-w; }
      if (y<h-1 && isBg[p+w] && !bg[p+w]) { bg[p+w]=true; stack[sp++]=p+w; }
    }
    int cnt = 0;
    for (int p=0;p<n;p++){ if (bg[p]) { int y=p/w,x=p-y*w,i=y*stride+x*4; b[i+3]=0; cnt++; } }
    return cnt;
  }
}
"@ -ReferencedAssemblies System.Drawing

$src = New-Object System.Drawing.Bitmap((Resolve-Path $inPath).Path)
$w = $src.Width; $h = $src.Height
# force a true 32bpp ARGB copy (upload may be 24bpp with no alpha channel)
$bm = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$gg = [System.Drawing.Graphics]::FromImage($bm); $gg.DrawImage($src, 0, 0, $w, $h); $gg.Dispose(); $src.Dispose()
$rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
$d = $bm.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$bytes = New-Object byte[] ($d.Stride * $h)
[System.Runtime.InteropServices.Marshal]::Copy($d.Scan0, $bytes, 0, $bytes.Length)
$cnt = [DeChecker]::Strip($bytes, $w, $h, $d.Stride, 22, 150)
[System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $d.Scan0, $bytes.Length)
$bm.UnlockBits($d)
$bm.Save((Join-Path (Get-Location).Path $outPath), [System.Drawing.Imaging.ImageFormat]::Png)
$bm.Dispose()
Write-Host "checker stripped: $cnt px -> transparent ($outPath)"

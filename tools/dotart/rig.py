# -*- coding: utf-8 -*-
"""リグ: 腕を外した胴・腕の置き場所・頭の裏に隠れる袖の下塗りを担当する。

見える細部(袖・カフ・拳)は part.py が承認済み原画から部品として取り出す。
ここで描く袖は「原画に写っていない部分を埋める下塗り」であり、寸法は原画への数値フィットで決めた値。
"""
import numpy as np
from PIL import Image, ImageDraw
from seg import CW, CH, XO, K, SK, SKS, WH, WHS, SUIT, SUITSH

X0 = XO + 1        # 旧試作の座標(体の左端=28)からのずれ。以下のx定数は「X0 + 試作時の値」で書く
SS = 8             # 図形のスーパーサンプリング倍率

def _ras(draw):
    im = Image.new('L', (CW*SS, CH*SS), 0); draw(ImageDraw.Draw(im))
    return np.asarray(im.resize((CW, CH), Image.BOX)) >= 128
def poly(pts): return _ras(lambda d: d.polygon([(p[0]*SS, p[1]*SS) for p in pts], fill=255))
def ell(c, rx, ry): return _ras(lambda d: d.ellipse([(c[0]-rx)*SS, (c[1]-ry)*SS, (c[0]+rx)*SS, (c[1]+ry)*SS], fill=255))
def dil(m):
    o = m.copy(); o[1:] |= m[:-1]; o[:-1] |= m[1:]; o[:, 1:] |= m[:, :-1]; o[:, :-1] |= m[:, 1:]; return o
def ero(m): return ~dil(~m)
def rot(v, deg):
    a = np.radians(deg); return np.array([v[0]*np.cos(a) - v[1]*np.sin(a), v[0]*np.sin(a) + v[1]*np.cos(a)])

# 主人公・左腕(画面左)。hero_up.png へのフィット結果(輪郭一致97.6%)。単位=ドット
HERO_ARM = dict(px=X0 + 56.5, py=109.4,   # 肩の回転中心
                angle=135.0,              # 挙手原画での腕の向き(0=真下, 時計回り)
                length=43.0, width=21.0,  # 肩->袖口 / 袖の太さ(一定。円錐にしない)
                cuff=4.2, band=0.29, back=9.0)

def find_seam(b):
    """袖と胴の縫い目線(K)を行ごとに探す。ここより左が腕"""
    seam = {}
    for cy in range(105, 152):
        y = cy - 2; g = (int(round(35 - (y - 105) * 8 / 25)) if y < 131 else 26) + 28 + X0
        seam[cy] = min((x for x in range(g-3, g+4) if b[cy, x] == K), key=lambda x: abs(x-g), default=g)
    return seam

def torso_without_arm(b, seam):
    """左腕(袖・カフ・拳)と頭を外した胴"""
    C = b.copy()
    for cy in range(105, 152): C[cy, :seam[cy]] = -1
    C[152:162, :X0 + 55] = -1; C[:105] = -1
    return C

def shoulder_zone(seam):
    """袖が上着を覆ってよい範囲=縫い目+5pxまで。ラペル・シャツは袖より手前"""
    allow = np.ones((CH, CW), bool)
    for cy in range(105, 152): allow[cy, seam[cy]+6:] = False
    return allow

def sleeve_underlay(P, angle):
    """頭の裏などに隠れる部分を埋める、太さ一定の袖(塗りと下側の影帯)"""
    piv = np.array([P['px'], P['py']]); u = rot(np.array([0.0, 1.0]), angle)
    n = np.array([u[1], -u[0]]); n = -n if n[1] > 0 else n       # n は常に上(明るい)側
    hw = P['width']/2; end = piv + u*P['length']; back = piv - u*P['back']
    s_lo, s_hi, e_lo, e_hi = back - n*hw, back + n*hw, end - n*hw, end + n*hw
    sleeve = poly([s_lo, e_lo, e_hi, s_hi]) | ell(piv, hw, hw)
    band = poly([s_lo, e_lo, e_lo + (e_hi-e_lo)*P['band'], s_lo + (s_hi-s_lo)*P['band']])
    A = np.full((CH, CW), -1); A[sleeve] = SUIT; A[sleeve & band] = SUITSH
    return A

def score(C, ref, box=None):
    """原画ラベルとの一致度(輪郭IoU, 部位ラベル一致)。腕まわりの矩形で測る"""
    x0, y0, x1, y1 = box or (X0 + 0, 50, X0 + 66, 126)
    a, r = C[y0:y1, x0:x1], ref[y0:y1, x0:x1]; uni = max(((a >= 0) | (r >= 0)).sum(), 1)
    return ((a >= 0) & (r >= 0)).sum() / uni, ((a == r) & (r >= 0)).sum() / uni

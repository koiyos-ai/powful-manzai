# -*- coding: utf-8 -*-
"""原画 -> 部位ラベル(構造) -> ドット。色ではなく「どの部位か」で打ち直す。

作業キャンバスは仕様幅(160)より広い WORK_W で持ち、書き出し時に仕様幅へ切り出す。
はみ出しは黙って切らず export() が必ず報告する。
"""
import numpy as np
from PIL import Image, ImageFilter
from collections import deque

SPEC_W, CH = 160, 192          # docs/SPRITE_SPEC.md
WORK_W = 256                   # 作業用(腕を真横に伸ばしても収まる幅)
CW = WORK_W
XO = (WORK_W - SPEC_W) // 2    # 仕様キャンバスの左端が作業キャンバスのどこか
HT, GROUND_PAD = 188, 2        # キャラの高さ / 上の余白

NAMES = ['K', 'hair', 'hairHi', 'skin', 'skinSh', 'cheek', 'white', 'whiteSh',
         'suit', 'suitSh', 'tie', 'tieSh', 'shoe', 'shoeSh', 'eye']
K, HAIR, HAIRHI, SK, SKS, CHEEK, WH, WHS, SUIT, SUITSH, TIE, TIESH, SHOE, SHOESH, EYE = range(15)
PAL = {
    'hero': [(26,18,22),(46,44,50),(112,112,120),(250,204,170),(238,160,125),(246,150,140),(250,250,250),(196,204,232),
             (236,22,28),(176,10,18),(250,212,44),(206,150,24),(120,56,38),(66,28,22),(72,72,78)],
}

def flood(cand):
    """四辺から cand を辿った領域(=背景)"""
    h, w = cand.shape; bg = np.zeros((h, w), bool); dq = deque()
    for x in range(w):
        for y in (0, h-1):
            if cand[y, x] and not bg[y, x]: bg[y, x] = True; dq.append((y, x))
    for y in range(h):
        for x in (0, w-1):
            if cand[y, x] and not bg[y, x]: bg[y, x] = True; dq.append((y, x))
    while dq:
        y, x = dq.popleft()
        for dy, dx in ((1,0),(-1,0),(0,1),(0,-1)):
            ny, nx = y+dy, x+dx
            if 0 <= ny < h and 0 <= nx < w and cand[ny, nx] and not bg[ny, nx]:
                bg[ny, nx] = True; dq.append((ny, nx))
    return bg

def labels_hi(path, pal):
    """原画の解像度のまま部位ラベル化(-1=背景)。背景は四隅から種類を自動判定(黒 / 焼き込み市松)"""
    im = Image.open(path).convert('RGB'); a = np.asarray(im).astype(np.int32)
    mx, mn = a.max(2), a.min(2)
    bg = flood(mx <= 3) if a[2, 2].max() < 10 else flood(((mx - mn) < 18) & (mn > 185))
    pc = np.array(pal, np.float32)
    bl = np.asarray(im.filter(ImageFilter.MedianFilter(5))).astype(np.float32)   # 面のノイズを吸収
    lab = ((bl[:, :, None, :] - pc[None, None, :, :]) ** 2).sum(3).argmin(2); lab[bg] = -1
    return lab

def fit_frame(lab):
    """原画px -> ドットの対応(s, ox, oy)。高さ=HT、脚(下20ドット)の中心=仕様キャンバスのx=80"""
    ys, xs = np.where(lab >= 0); y0, y1 = ys.min(), ys.max() + 1
    s = (y1 - y0) / HT
    legs = np.where(lab[int(y1 - 20*s):y1] >= 0)[1]
    cx = (legs.min() + legs.max() + 1) / 2
    return (s, cx - (XO + SPEC_W/2) * s, y0 - GROUND_PAD * s)

def down(lab, frame, npal=15):
    """ブロック内のラベル多数決で1ドットを決める。輪郭(K)は細線なので34%で採用"""
    s, ox, oy = frame; h, w = lab.shape; res = np.full((CH, CW), -1)
    for cy in range(CH):
        for cx in range(CW):
            ya, yb, xa, xb = int(oy+cy*s), int(oy+(cy+1)*s)+1, int(ox+cx*s), int(ox+(cx+1)*s)+1
            if yb <= 0 or xb <= 0 or ya >= h or xa >= w: continue
            blk = lab[max(ya, 0):yb, max(xa, 0):xb].ravel(); n = blk.size
            if n == 0: continue
            cnt = np.bincount(blk + 1, minlength=npal + 1)
            if cnt[0] > n * 0.5: continue
            if cnt[1] >= n * 0.34: res[cy, cx] = K; continue
            cnt[0] = 0; res[cy, cx] = cnt.argmax() - 1
    return res

def despeckle(res, rounds=2):
    """4近傍に同じラベルが無い孤立ドットを、近傍の多数へ寄せる"""
    for _ in range(rounds):
        r2 = res.copy()
        for y in range(1, CH-1):
            for x in range(1, CW-1):
                v = res[y, x]
                if v < 0: continue
                nb = [res[y-1, x], res[y+1, x], res[y, x-1], res[y, x+1]]
                if v not in nb:
                    nn = [q for q in nb if q >= 0]
                    if nn: r2[y, x] = max(set(nn), key=nn.count)
        res = r2
    return res

def segment(path, pal, frame=None):
    lab = labels_hi(path, pal)
    if frame is None: frame = fit_frame(lab)
    return despeckle(down(lab, frame)), frame, lab

def to_image(C, pal, scale=1):
    o = Image.new('RGBA', (C.shape[1], C.shape[0])); px = o.load()
    for y, x in zip(*np.where(C >= 0)): px[int(x), int(y)] = tuple(pal[C[y, x]]) + (255,)
    return o.resize((o.width*scale, o.height*scale), Image.NEAREST) if scale > 1 else o

def needed_width(C):
    """体中心を保ったまま全ドットを収めるのに必要なキャンバス幅(偶数)"""
    xs = np.where(C >= 0)[1]; c = XO + SPEC_W/2
    return int(2 * np.ceil(max(c - xs.min(), xs.max() + 1 - c)))

def export(C, pal, path, width=SPEC_W):
    """仕様幅へ切り出して保存。はみ出すなら保存せず必要幅を返す(黙って切らない)"""
    need = needed_width(C)
    if np.where(C >= 0)[1].min() == 0 or np.where(C >= 0)[1].max() == CW - 1:
        raise ValueError('作業キャンバス(%d)からもはみ出している' % CW)
    if need > width: return False, need
    x0 = XO + (SPEC_W - width)//2
    to_image(C[:, x0:x0+width], pal).save(path)
    return True, need

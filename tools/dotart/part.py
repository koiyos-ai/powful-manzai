# -*- coding: utf-8 -*-
"""部品: 承認済み原画から腕(袖+カフ+拳)を高解像度ラベルのまま取り出し、肩を軸に回して使う。

形は100%原画由来(PXFEEDBACK R-08)。回転は原画解像度で行い、その後ドットへ打ち直すので
ドットのジャギーが回転で崩れない。
"""
import numpy as np
from PIL import Image
from collections import deque
import seg, rig
from seg import CW, CH, K, SK, SKS, WH, WHS, SUIT, SUITSH, SHOESH
from rig import X0

def fill(lab, seed, ok, limit=None):
    m = np.zeros(lab.shape, bool)
    if lab[seed[1], seed[0]] not in ok: return m
    dq = deque([seed]); m[seed[1], seed[0]] = True
    while dq:
        x, y = dq.popleft()
        for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
            nx, ny = x+dx, y+dy
            if 0 <= nx < CW and 0 <= ny < CH and not m[ny, nx] and lab[ny, nx] in ok and (limit is None or limit[ny, nx]):
                m[ny, nx] = True; dq.append((nx, ny))
    return m

class ArmPart:
    def __init__(self, hi, ref, frame, base):
        self.frame = frame
        seam = rig.find_seam(base); lim = rig.shoulder_zone(seam)
        lim[126:] = False; lim[:, X0 + 70:] = False
        sleeve = fill(ref, (X0 + 30, 95), (SUIT, SUITSH, SHOESH), lim)
        cuff = np.zeros_like(sleeve)
        for sd in ((24, 82), (29, 76), (22, 83), (26, 80)): cuff |= fill(ref, (X0 + sd[0], sd[1]), (WH, WHS), lim)
        self.fist = fill(ref, (X0 + 19, 67), (SK, SKS, WH), lim)
        ys, xs = np.where(self.fist); self.fist_c = np.array([(xs.min()+xs.max())/2, (ys.min()+ys.max())/2])
        body = sleeve | cuff | self.fist
        self.mask = body | (rig.dil(rig.dil(body)) & (ref == K) & lim)       # 外周2px以内の輪郭だけ連れていく
        s, ox, oy = frame
        yy, xx = np.mgrid[0:hi.shape[0], 0:hi.shape[1]]
        cx = np.clip(((xx - ox) / s).astype(int), 0, CW-1); cy = np.clip(((yy - oy) / s).astype(int), 0, CH-1)
        self.hi_part = np.where(self.mask[cy, cx], hi, -1)

    def layer(self, pivot, delta=0.0, relight=False):
        """肩まわりに delta 度まわした部品をドットへ打ち直す。
        relight=True: 鏡像で使う腕用。形は鏡像でよいが光は鏡像にしない(光源は常に右上)ので、
        拳の内側(ハイライトと影)だけを拳の中心で左右に入れ替えておく。"""
        s, ox, oy = self.frame
        if abs(delta) < 1e-6:
            L = seg.down(self.hi_part, self.frame)
        else:
            im = Image.fromarray((self.hi_part + 1).astype(np.uint8), 'L')
            r = im.rotate(-delta, resample=Image.NEAREST, center=(ox + pivot[0]*s, oy + pivot[1]*s))
            L = seg.down(np.asarray(r).astype(np.int32) - 1, self.frame)
        if relight:
            c = np.array(pivot) + rig.rot(self.fist_c - np.array(pivot), delta)
            F = fill(L, (int(round(c[0])), int(round(c[1]))), (SK, SKS, WH))
            if F.any():
                xs = np.where(F)[1]; ax = xs.min() + xs.max()
                L2 = L.copy()
                for y, x in zip(*np.where(F)):
                    if 0 <= ax - x < CW and F[y, ax - x]: L2[y, x] = L[y, ax - x]
                L = L2
        return L

def pose(base, part, P, side='L', delta=0.0):
    """base に、腕を delta 度まわしたポーズを合成する。side='R' は体の中心で鏡像にして同じ処理"""
    b = base if side == 'L' else base[:, ::-1]      # 体中心=作業キャンバス中心なので、この反転は体の中心まわり
    seam = rig.find_seam(b); allow = rig.shoulder_zone(seam)
    C = rig.torso_without_arm(b, seam)
    A = rig.sleeve_underlay(P, P['angle'] + delta)
    under = (A >= 0) & (C < 0)
    C[under] = A[under]
    L = part.layer((P['px'], P['py']), delta, relight=(side == 'R'))
    keep = (L >= 0) & (allow | (C < 0) | (b < 0))
    C[keep] = L[keep]
    hm = np.zeros((CH, CW), bool); hm[:105] = b[:105] >= 0
    C[hm] = b[hm]                                   # 頭・耳は袖より手前
    op = C >= 0
    C[op & (C != K) & rig.dil(~op) & ~hm] = K       # 透過に接する塗りは輪郭にする(継ぎ目で線を切らない)
    return C if side == 'L' else C[:, ::-1]

# -*- coding: utf-8 -*-
"""欠陥の自動検出。人に見せる前に必ず通す。
  double_lines : 輪郭(K)が1〜2ドットの塗りを挟んで平行に走る箇所(二重線・はみ出した下塗り)
  bare_fill    : 輪郭なしで透過に接している塗り(線の途切れ)
  specks       : 4近傍に同じラベルが無い孤立ドット
"""
import numpy as np
from collections import deque
from seg import K

def _components(m, minsize):
    h, w = m.shape; seen = np.zeros_like(m); out = []
    for y, x in zip(*np.where(m)):
        if seen[y, x]: continue
        dq = deque([(y, x)]); seen[y, x] = True; pts = []
        while dq:
            a, b = dq.popleft(); pts.append((a, b))
            for da in (-1, 0, 1):
                for db in (-1, 0, 1):
                    c, d = a+da, b+db
                    if 0 <= c < h and 0 <= d < w and m[c, d] and not seen[c, d]: seen[c, d] = True; dq.append((c, d))
        if len(pts) >= minsize: out.append(pts)
    return out

def double_lines(C, minlen=8):
    """塗りドットで、上下または左右のどちらかの向きに『K/透過 - 塗り1〜2個 - K』と挟まれているものの連なり"""
    h, w = C.shape; fillm = (C >= 0) & (C != K); isk = C == K; thin = np.zeros((h, w), bool)
    for dy, dx in ((0, 1), (1, 0)):
        for y in range(2, h-2):
            for x in range(2, w-2):
                if not fillm[y, x]: continue
                a = 1
                while a <= 2 and fillm[y - dy*a, x - dx*a]: a += 1
                b = 1
                while b <= 2 and fillm[y + dy*b, x + dx*b]: b += 1
                if a + b - 1 <= 2:
                    p, q = (y - dy*a, x - dx*a), (y + dy*b, x + dx*b)
                    ends = [isk[p], isk[q], C[p] < 0, C[q] < 0]
                    if (ends[0] and (ends[1] or ends[3])) or (ends[1] and ends[2]): thin[y, x] = True
    return _components(thin, minlen)

def bare_fill(C):
    op = C >= 0; t = ~op
    nb = np.zeros_like(op); nb[1:] |= t[:-1]; nb[:-1] |= t[1:]; nb[:, 1:] |= t[:, :-1]; nb[:, :-1] |= t[:, 1:]
    return int((op & (C != K) & nb).sum())

def specks(C):
    n = 0
    for y, x in zip(*np.where(C >= 0)):
        if 0 < y < C.shape[0]-1 and 0 < x < C.shape[1]-1 and C[y, x] not in (C[y-1, x], C[y+1, x], C[y, x-1], C[y, x+1]): n += 1
    return n

def report(name, C, baseline=None):
    dl = double_lines(C)
    if baseline is not None:      # 原画由来の細い面(カフ・ラペル等)は欠陥ではないので、baseにも在るものは除く
        bm = np.zeros(C.shape, bool)
        for pts in double_lines(baseline, 1):
            for p in pts: bm[p] = True
        dl = [pts for pts in dl if sum(not bm[p] for p in pts) >= 8]
    boxes = [(min(p[1] for p in pts), min(p[0] for p in pts), max(p[1] for p in pts), max(p[0] for p in pts), len(pts)) for pts in dl]
    print('%-12s 二重線 %d箇所 %s / 線の途切れ %d / 孤立ドット %d' % (name, len(dl), boxes, bare_fill(C), specks(C)))
    return dl

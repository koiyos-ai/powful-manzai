# -*- coding: utf-8 -*-
"""主人公のスプライトを原画から生成する。
  python3 tools/dotart/build_hero.py            -> images/px2/ に書き出し + 検証値を表示
依存: Python3, numpy, Pillow
"""
import os, sys, numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import seg, rig, part
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SRC, OUT = os.path.join(ROOT, 'images'), os.path.join(ROOT, 'images', 'px2')

def build(verbose=True):
    pal = seg.PAL['hero']
    base, frame, _ = seg.segment(os.path.join(SRC, 'hero.png'), pal)
    hi = seg.labels_hi(os.path.join(SRC, 'hero_up.png'), pal)
    ref = seg.despeckle(seg.down(hi, frame))                 # 挙手原画(正解データ)。baseと同じ枠で読む
    arm = part.ArmPart(hi, ref, frame, base)
    P = rig.HERO_ARM
    out = {'hero_base': base,
           'hero_upL': part.pose(base, arm, P, 'L'),
           'hero_upR': part.pose(base, arm, P, 'R')}
    if verbose:
        legs = np.where(base[-22:-2] >= 0)[1]
        print('脚の中心x(仕様キャンバス) = %.1f  (規定: 79.5 = x=80の境界)' % ((legs.min()+legs.max())/2 - seg.XO))
        print('挙手左 vs 承認済み原画: 輪郭一致 %.3f / 部位ラベル一致 %.3f' % rig.score(out['hero_upL'], ref))
    return out, pal, dict(ref=ref, arm=arm, base=base, frame=frame)

if __name__ == '__main__':
    out, pal, ctx = build()
    os.makedirs(OUT, exist_ok=True)
    for name, C in out.items():
        ok, need = seg.export(C, pal, os.path.join(OUT, name + '.png'))
        ncol = len(set(C[C >= 0].tolist()))
        print('%-10s %s  必要幅=%d  色数=%d' % (name, '書き出しOK' if ok else '★はみ出し: 書き出していない', need, ncol))
    # 見切れの検査: 腕を回したとき、体中心を保って収めるのに必要なキャンバス幅
    print('--- 腕の角度ごとの必要幅(仕様は%d) ---' % seg.SPEC_W)
    for delta in (20, 0, -20, -45, -70, -90):
        C = part.pose(ctx['base'], ctx['arm'], rig.HERO_ARM, 'L', delta)
        print('  挙手から %+4d度: 必要幅 %d %s' % (delta, seg.needed_width(C), '' if seg.needed_width(C) <= seg.SPEC_W else '← 160に入らない'))

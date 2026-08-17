#!/usr/bin/env python3
"""Render a VCD dump as a clean digital timing diagram PNG (for the portfolio).

Usage:
  python tools/vcd_wave.py --vcd sim/sequencer_tb.vcd --out docs/waves/sequencer.png \
         --signals clk,rst,phase --tmax 160000 --title "5-phase sequencer"

--signals is a comma-list of leaf names (in top-to-bottom order); omit for all.
--tmax is in raw VCD time units (0 = full run). 1-bit signals draw as 0/1 steps;
multi-bit buses draw as a band with the hex value labelled per segment.
"""
import argparse
from vcdvcd import VCDVCD
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt


def leaf(name):
    return name.split('.')[-1].split('[')[0]


def to_hex(v):
    v = v[1:] if v.startswith('b') else v
    if v and set(v) <= set('01'):
        return format(int(v, 2), 'X')
    return v  # x / z / unknown


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--vcd', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--signals', default='')
    ap.add_argument('--tmax', type=float, default=0)
    ap.add_argument('--title', default='')
    args = ap.parse_args()

    vcd = VCDVCD(args.vcd)
    allnames = list(vcd.signals)

    if args.signals:
        chosen = []
        for w in [s.strip() for s in args.signals.split(',') if s.strip()]:
            m = next((n for n in allnames if leaf(n) == w), None)
            if m:
                chosen.append((w, m))
            else:
                print('  (signal not found:', w, ')')
    else:
        seen = {}
        for n in allnames:
            l = leaf(n)
            if l not in seen or len(n) < len(seen[l]):
                seen[l] = n
        chosen = [(l, seen[l]) for l in seen]

    tmax = args.tmax if args.tmax > 0 else float(vcd.endtime or 1)
    if tmax <= 0:
        tmax = 1

    LANE, GAP = 1.0, 0.7
    fig, ax = plt.subplots(figsize=(12, max(2.2, 0.75 * len(chosen) + 1)))
    bg, line, txt, grid = '#0d1117', '#58d3ff', '#e6e7ea', '#21262d'
    fig.patch.set_facecolor(bg); ax.set_facecolor(bg)

    yticks, ylabels, y = [], [], 0.0
    for name, full in reversed(chosen):        # first listed signal on top
        sig = vcd[full]
        tv = list(sig.tv)
        try:
            size = int(getattr(sig, 'size', 0))
        except (TypeError, ValueError):
            size = 0
        segs = []
        for i, (t, v) in enumerate(tv):
            t0 = float(t)
            t1 = float(tv[i + 1][0]) if i + 1 < len(tv) else tmax
            if t0 >= tmax:
                break
            segs.append((t0, min(t1, tmax), v))
        if not segs:
            segs = [(0.0, tmax, 'x')]

        onebit = size == 1 or all(len(to_hex(v)) <= 1 and to_hex(v) in '01xz' for _, _, v in segs)
        if onebit:
            for i, (t0, t1, v) in enumerate(segs):
                lv = 1 if (v[-1] == '1') else 0
                yy = y + (LANE if lv else 0)
                ax.plot([t0, t1], [yy, yy], color=line, lw=2)
                if i:
                    ax.plot([t0, t0], [y, y + LANE], color=line, lw=2)
        else:
            for i, (t0, t1, v) in enumerate(segs):
                ax.plot([t0, t1], [y, y], color=line, lw=1.5)
                ax.plot([t0, t1], [y + LANE, y + LANE], color=line, lw=1.5)
                if i:
                    ax.plot([t0, t0], [y, y + LANE], color=line, lw=1.5)
                ax.text((t0 + t1) / 2, y + LANE / 2, to_hex(v), ha='center', va='center',
                        color=txt, fontsize=9, family='monospace')
        yticks.append(y + LANE / 2); ylabels.append(name)
        y += LANE + GAP

    ax.set_yticks(yticks); ax.set_yticklabels(ylabels, color=txt, family='monospace', fontsize=10)
    ax.set_xlim(0, tmax); ax.set_ylim(-0.3, y)
    ax.set_xlabel('time (VCD units)', color=txt)
    ax.tick_params(colors=txt)
    for s in ax.spines.values():
        s.set_color('#30363d')
    ax.grid(axis='x', color=grid, lw=0.5)
    if args.title:
        ax.set_title(args.title, color=txt, fontsize=13, fontweight='bold')
    plt.tight_layout()
    plt.savefig(args.out, dpi=130, facecolor=bg)
    print('wrote', args.out, '| signals:', [c[0] for c in chosen], '| tmax:', tmax)


if __name__ == '__main__':
    main()

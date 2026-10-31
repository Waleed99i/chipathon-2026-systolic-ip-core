#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Compare a replayed run with the committed final layout.

Usage: python3 reproduce/compare.py librelane/runs/<tag>

1. The committed reference files must have their recorded hashes.
2. Signoff metrics of the replayed run: every violation count zero, in total
   and per corner; non-negative worst slack in all nine corners.
3. Powered netlist: byte-identical to verilog/gl/chip_core.pnl.v.
4. GDS: top cell, database unit and 1675 x 1675 um boundary; then either
   byte-identical to gds/chip_core.gds, or identical in every polygon and
   every text label on every layer (KLayout). In the second case the result
   says so explicitly; it does not claim the files differ only in timestamps.
Exit status 0 means the committed layout was reproduced.
"""
import hashlib
import json
import math
import sys
from pathlib import Path

GDS_SHA = '76091ccb1052a45195f3b30766380e44a60ad4da4ac7ed8a1dac7dec226a87e3'
PNL_SHA = '42821194c1447902f4022622f8daba5143bb3bd526fd32fb5e811a8fcb7a5410'
CORNERS = [f'{c}_{p}' for c in ('nom', 'min', 'max')
           for p in ('tt_025C_5v00', 'ss_125C_4v50', 'ff_n40C_5v50')]
ZERO = [
    'design__max_slew_violation__count', 'design__max_cap_violation__count',
    'design__max_fanout_violation__count', 'timing__setup_vio__count',
    'timing__hold_vio__count', 'timing__setup__wns', 'timing__hold__wns',
    'timing__setup__tns', 'timing__hold__tns', 'route__drc_errors',
    'magic__drc_error__count', 'klayout__drc_error__count',
    'antenna__violating__nets', 'antenna__violating__pins',
    'route__antenna_violation__count', 'design__lvs_error__count',
    'design__lvs_device_difference__count',
    'design__lvs_net_difference__count', 'design__lvs_property_fail__count',
    'design__lvs_unmatched_device__count', 'design__lvs_unmatched_net__count',
    'design__lvs_unmatched_pin__count',
    'design__critical_disconnected_pin__count',
]


def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def check_metrics(m):
    bad = []
    for key in ZERO:
        v = m.get(key)
        if v is None or float(v) != 0:
            bad.append(f'{key} = {v}')
    for c in CORNERS:
        for key in (f'timing__setup_vio__count__corner:{c}',
                    f'timing__hold_vio__count__corner:{c}',
                    f'design__max_slew_violation__count__corner:{c}',
                    f'design__max_cap_violation__count__corner:{c}',
                    f'design__max_fanout_violation__count__corner:{c}'):
            v = m.get(key)
            if v is None or float(v) != 0:
                bad.append(f'{key} = {v}')
        for kind in ('setup', 'hold'):
            key = f'timing__{kind}__ws__corner:{c}'
            v = m.get(key)
            if v is None or not math.isfinite(float(v)) or float(v) < 0:
                bad.append(f'{key} = {v}')
    return bad


def load(path):
    import klayout.db as kdb
    layout = kdb.Layout()
    layout.read(str(path))
    return layout


def check_frame(layout):
    tops = list(layout.top_cells())
    if len(tops) != 1 or tops[0].name != 'chip_core':
        return 'unexpected top cells'
    if abs(layout.dbu - 0.001) > 1e-12:
        return f'unexpected database unit {layout.dbu}'
    b, d = tops[0].bbox(), layout.dbu
    box = [b.left * d, b.bottom * d, b.right * d, b.top * d]
    if any(abs(x - y) > 1e-6 for x, y in zip(box, [0, 0, 1675, 1675])):
        return f'unexpected boundary {box}'
    return None


def compare_geometry(la, lb):
    import klayout.db as kdb
    ta, tb = la.top_cell(), lb.top_cell()
    layers = {(i.layer, i.datatype) for i in la.layer_infos()}
    layers |= {(i.layer, i.datatype) for i in lb.layer_infos()}
    poly = text = 0
    for layer, datatype in sorted(layers):
        ia, ib = la.find_layer(layer, datatype), lb.find_layer(layer, datatype)
        ra = kdb.Region(ta.begin_shapes_rec(ia)) if ia is not None else kdb.Region()
        rb = kdb.Region(tb.begin_shapes_rec(ib)) if ib is not None else kdb.Region()
        xa = kdb.Texts(ta.begin_shapes_rec(ia)) if ia is not None else kdb.Texts()
        xb = kdb.Texts(tb.begin_shapes_rec(ib)) if ib is not None else kdb.Texts()
        p = (ra ^ rb).count()
        sa = sorted((t.string, t.x, t.y) for t in xa.each())
        sb = sorted((t.string, t.x, t.y) for t in xb.each())
        t = 0 if sa == sb else max(1, len(set(sa) ^ set(sb)))
        if p or t:
            print(f'     layer {layer}/{datatype}: {p} differing polygons, '
                  f'{t} differing labels')
        poly += p
        text += t
    return len(layers), poly, text


def main():
    run = Path(sys.argv[1])
    repo = Path(__file__).resolve().parent.parent
    ref_gds, ref_pnl = repo / 'gds/chip_core.gds', repo / 'verilog/gl/chip_core.pnl.v'
    if sha(ref_gds) != GDS_SHA or sha(ref_pnl) != PNL_SHA:
        print('STOP: the committed reference GDS or netlist is not the recorded one')
        return 1
    print('OK   committed reference GDS and netlist have the recorded hashes')
    ok = True

    m = json.loads((run / 'final/metrics.json').read_text())
    bad = check_metrics(m)
    for line in bad:
        print('FAIL', line)
    ok &= not bad
    if not bad:
        print(f'OK   {len(ZERO)} signoff counts zero; setup/hold/slew/cap/fanout '
              f'zero and worst slack non-negative in all {len(CORNERS)} corners')
    print(f'     worst setup slack {m.get("timing__setup__ws")} ns, '
          f'worst hold slack {m.get("timing__hold__ws")} ns '
          '(recorded run: 0.5499 / 0.0912)')

    same_pnl = sha(run / 'final/pnl/chip_core.pnl.v') == PNL_SHA
    print(('OK  ' if same_pnl else 'FAIL') +
          ' powered netlist byte-identical to verilog/gl/chip_core.pnl.v')
    ok &= same_pnl

    gds = run / 'final/gds/chip_core.gds'
    new = load(gds)
    problem = check_frame(new)
    print(('FAIL ' + problem) if problem else
          'OK   GDS top cell chip_core, DBU 0.001 um, boundary 1675 x 1675 um')
    ok &= problem is None
    if sha(gds) == GDS_SHA:
        print('OK   GDS byte-identical to gds/chip_core.gds')
    else:
        print('     GDS bytes differ; comparing every polygon and label...')
        n, poly, text = compare_geometry(new, load(ref_gds))
        good = poly == 0 and text == 0
        print(('OK  ' if good else 'FAIL') + f' GDS geometry and labels identical '
              f'on all {n} layers ({poly} polygon and {text} label differences); '
              'file bytes differ')
        ok &= good
    print('REPRODUCED: matches the committed layout' if ok
          else 'NOT REPRODUCED: see the lines marked FAIL')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())

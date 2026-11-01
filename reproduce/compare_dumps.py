"""Summarize the difference between two dump_odb.tcl outputs (diagnosis only)."""
import sys
from pathlib import Path

ECO_INSTANCES = ['_29775_', '_34089_', '_29733_', 'clkbuf_leaf_259_clk',
                 'clkbuf_leaf_257_clk', 'clkbuf_leaf_541_clk', 'clkbuf_leaf_519_clk']


def load(path):
    die, insts, nets = None, {}, {}
    for line in Path(path).read_text().splitlines():
        f = line.split('\t')
        if f[0] == 'DIE':
            die = tuple(f[1:])
        elif f[0] == 'I':
            insts[f[1]] = tuple(f[2:])
        elif f[0] == 'N':
            nets[f[1]] = tuple(f[2:])
    return die, insts, nets


def main():
    die_a, ia, na = load(sys.argv[1])
    die_b, ib, nb = load(sys.argv[2])
    print('Structural comparison: checkpoint B vs rebuilt')
    print(f'die area      {"same" if die_a == die_b else f"{die_a} vs {die_b}"}')
    common = ia.keys() & ib.keys()
    print(f'instances     {len(ia)} vs {len(ib)}; {len(common)} names in both, '
          f'{len(ia.keys() - ib.keys())} only in B, {len(ib.keys() - ia.keys())} only in rebuilt')
    cell = [n for n in common if ia[n][0] != ib[n][0]]
    place = [n for n in common if ia[n][0] == ib[n][0] and ia[n][1:] != ib[n][1:]]
    print(f'same name, different cell        {len(cell)}')
    print(f'same name and cell, moved        {len(place)}')
    print(f'identical instances              {len(common) - len(cell) - len(place)}')
    ncommon = na.keys() & nb.keys()
    print(f'nets          {len(na)} vs {len(nb)}; {len(ncommon)} names in both, '
          f'{sum(na[n] != nb[n] for n in ncommon)} with different terminal counts')
    for name in ECO_INSTANCES:
        a, b = ia.get(name), ib.get(name)
        print(f'ECO instance {name}: B {a[0] if a else "missing"}, rebuilt {b[0] if b else "missing"}')
    for label, names in (('different cell', cell), ('moved', place)):
        for n in sorted(names)[:10]:
            print(f'  {label}: {n}  B {ia[n]}  rebuilt {ib[n]}')


if __name__ == '__main__':
    main()

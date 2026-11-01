"""Compare a rebuild's steps and resolved settings with the recorded FULL2/FULL3 runs.

usage: python3 reproduce/compare_records.py <REPO> <PDK_ROOT> <stage1 run dir> <stage2 run dir>

Paths in the records are those of the original machine; they are mapped to
this repository and PDK before comparing. Differences are reported, not hidden.
"""
import json
import sys
from pathlib import Path

ORIG_REPO = '/home/rumali/openlane_project/a34-rtl-fix-pd'
ORIG_PDK = '/home/rumali/openlane_project/chipathon-2026-systolic-ip-core-main-git/gf180mcu'


def number(step):
    head = step.split('-', 1)[0]
    return int(head) if head.isdigit() else None


def steps(run, last):
    names = [p.name for p in Path(run).iterdir() if p.is_dir() and number(p.name) is not None]
    extra = sorted(n for n in names if number(n) > last)
    if extra:
        print(f'  note: {len(extra)} steps after step {last:02d} also ran ({extra[0]} ... {extra[-1]})')
    return sorted((n for n in names if number(n) <= last), key=number)


def recorded_steps(name, last):
    lines = Path(f'reproduce/records/{name}_steps.txt').read_text().split()
    return [s for s in lines if number(s) is not None and number(s) <= last]


def normalize(value, repo, pdk):
    text = json.dumps(value, sort_keys=True)
    return json.loads(text.replace(ORIG_PDK, pdk).replace(ORIG_REPO, repo))


def compare_config(name, run, repo, pdk):
    rec = normalize(json.loads(Path(f'reproduce/records/{name}_resolved.json').read_text()), repo, pdk)
    got = json.loads((Path(run) / 'resolved.json').read_text())
    keys = sorted((rec.keys() | got.keys()) - {'meta'})
    diff = [k for k in keys if rec.get(k) != got.get(k)]
    print(f'{name} settings: {len(keys)} compared, {len(diff)} differ')
    for k in diff:
        print(f'  {k}: recorded {json.dumps(rec.get(k))[:160]}')
        print(f'  {" " * len(k)}  rebuild  {json.dumps(got.get(k))[:160]}')
    return not diff


def main():
    repo, pdk, run1, run2 = sys.argv[1:5]
    ok = True
    for name, run, last in (('FULL2', run1, 40), ('FULL3', run2, 4)):
        got, rec = steps(run, last), recorded_steps(name, last)
        same = got == rec
        ok &= same
        print(f'{name} steps 01-{last:02d}: {"identical" if same else "DIFFERENT"} ({len(got)} run, {len(rec)} recorded)')
        if not same:
            for a, b in zip(got + [''] * len(rec), rec + [''] * len(got)):
                if a != b:
                    print(f'  run {a or "-"}  recorded {b or "-"}')
        ok &= compare_config(name, run, repo, pdk)
    print('RECORDS MATCH' if ok else 'RECORDS DIFFER (see above)')


if __name__ == '__main__':
    main()

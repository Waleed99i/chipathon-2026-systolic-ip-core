"""Fail closed on known source/config/library mismatches; no design edits."""
import argparse
import hashlib
import importlib.metadata
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RECORD = json.loads((ROOT / 'reproduce/recorded_inputs.json').read_text())

def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()

def verify(base, entries):
    for rel, expected in entries.items():
        path = base / rel
        if not path.is_file() or sha(path) != expected:
            raise RuntimeError(f'Missing or changed recorded input: {path}')

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--repo-only', action='store_true')
    ap.add_argument('pdk', nargs='?', type=Path)
    args = ap.parse_args()
    verify(ROOT, RECORD['repo'])
    expected = {p for p in RECORD['repo'] if p.startswith('src/rtl/')}
    actual = {str(p.relative_to(ROOT)) for ext in ('*.v', '*.sv')
              for p in (ROOT / 'src/rtl').glob(ext)}
    if actual != expected:
        raise RuntimeError('RTL file set differs; review before simulation/replay')
    if not args.repo_only:
        if args.pdk is None:
            ap.error('Supply PDK_ROOT or use --repo-only')
        verify(args.pdk.resolve(), RECORD['pdk'])
        if importlib.metadata.version('librelane') != RECORD['librelane']:
            raise RuntimeError('LibreLane version differs; use the locked project shell')
        v = subprocess.run(['openroad', '-version'], capture_output=True, text=True, check=True)
        if RECORD['openroad'] not in v.stdout + v.stderr:
            raise RuntimeError('OpenROAD version differs; use the locked project shell')
    print('RECORDED INPUT CHECK PASS' + (' (repository only)' if args.repo_only else ' (repository/tools/key PDK inputs)'))

if __name__ == '__main__':
    main()

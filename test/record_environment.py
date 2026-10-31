"""Record exactly what was simulated. Does not declare a test pass."""
import hashlib
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

repo = Path(__file__).resolve().parent.parent
out = Path(sys.argv[1])
paths = list((repo / 'src/rtl').glob('*.v')) + list((repo / 'src/rtl').glob('*.sv'))
paths += list((repo / 'test').glob('*'))
paths += [repo / 'src/chipathon_wrapper/chip_core.sv', repo / 'verilog/gl/chip_core.pnl.v']
if sys.argv[2]:
    v = Path(sys.argv[2]) / 'gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/verilog'
    paths += [v / 'primitives.v', v / 'gf180mcu_fd_sc_mcu7t5v0.v']
def command(args):
    p = subprocess.run(args, cwd=repo, capture_output=True, text=True)
    return {'exit': p.returncode, 'stdout': p.stdout, 'stderr': p.stderr}
record = {
    'utc': datetime.now(timezone.utc).isoformat(),
    'git': command(['git', 'rev-parse', 'HEAD']),
    'status': command(['git', 'status', '--short']),
    'iverilog': command(['iverilog', '-V']),
    'python': sys.version,
    'sha256': {str(p): hashlib.sha256(p.read_bytes()).hexdigest()
               for p in paths if p.is_file()},
    'scope': 'Zero-delay simulation; not STA, formal equivalence, or silicon testing.',
}
with (out / 'provenance.json').open('x') as f:
    json.dump(record, f, indent=2)

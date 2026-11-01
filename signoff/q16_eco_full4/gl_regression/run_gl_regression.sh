#!/usr/bin/env bash
# Test-only regression of the frozen c98ec31 implementation. No PD or Git writes.
set -euo pipefail
PDK_ROOT=${1:?give the PDK root containing gf180mcuD/}
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../.." && pwd)
PDK_ROOT=$(cd "$PDK_ROOT" && pwd)
V=$PDK_ROOT/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/verilog
for tool in python3 iverilog vvp timeout git; do command -v "$tool" >/dev/null; done
python3 -c 'import numpy'
mkdir -p "$REPO/verification_results"
OUT=$(mktemp -d "$REPO/verification_results/gl-regression-XXXXXXXX")
trap 'status=$?; if [ "$status" -ne 0 ]; then echo "REGRESSION STOPPED (exit $status). Logs: $OUT" >&2; fi' EXIT
cd "$OUT"

python3 - "$REPO" "$V" "$HERE" <<'PY'
import hashlib,json,subprocess,sys
from pathlib import Path
import numpy as np
repo, models, here = map(Path, sys.argv[1:])
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
expected = {
 'verilog/gl/chip_core.pnl.v':'42821194c1447902f4022622f8daba5143bb3bd526fd32fb5e811a8fcb7a5410',
 'gds/chip_core.gds':'76091ccb1052a45195f3b30766380e44a60ad4da4ac7ed8a1dac7dec226a87e3',
}
manifest=json.loads((here.parent/'eco_run_manifest.json').read_text())
for path,digest in manifest['protected_sha256'].items():
 for prefix in ('src/rtl/','src/chipathon_wrapper/'):
  marker='/'+prefix
  if marker in path:
   expected[prefix+path.split(marker,1)[1]]=digest
for rel,digest in expected.items():
 p=repo/rel
 if not p.is_file() or sha(p)!=digest: raise SystemExit(f'STOP: implementation differs from reviewed ECO: {rel}')
model_hashes={}
for name in ('primitives.v','gf180mcu_fd_sc_mcu7t5v0.v'):
 p=models/name
 if not p.is_file(): raise SystemExit(f'Missing standard-cell simulation model: {p}')
 model_hashes[str(p)]=sha(p)
provenance={
 'git_head':subprocess.check_output(['git','-C',str(repo),'rev-parse','HEAD'],text=True).strip(),
 'git_status':subprocess.check_output(['git','-C',str(repo),'status','--short'],text=True),
 'implementation_sha256':expected,'model_sha256':model_hashes,
 'test_sha256':{p.name:sha(p) for p in sorted(here.iterdir()) if p.is_file()},
 'python':sys.version,'numpy':np.__version__,
 'scope':'Zero-delay FUNCTIONAL models, no SDF, internal-handshake-assisted packets; reset per matrix.'
}
Path('provenance.json').write_text(json.dumps(provenance,indent=2)+'\n')
print('PREFLIGHT PASS: final GDS/netlist and corrected RTL hashes match the reviewed ECO.')
PY

iverilog -V > iverilog_version.txt 2>&1
python3 "$HERE/gen_cases.py"
iverilog -g2012 -s counter_tb -o counter.vvp "$REPO/src/rtl/counter.v" \
    "$REPO/src/tb/counter_tb.sv" > counter_compile.log 2>&1
 timeout 600s vvp -n counter.vvp > counter.log 2>&1
cat counter.log
iverilog -g2012 -s mtb -o rtl.vvp "$REPO"/src/rtl/*.v "$REPO"/src/rtl/*.sv \
    "$REPO/src/chipathon_wrapper/chip_core.sv" "$HERE/mtb.sv" > rtl_compile.log 2>&1
echo "Running 33 RTL cases..."
timeout 600s vvp -n rtl.vvp +N=33 > rtl.log 2>&1
iverilog -g2012 -s mtb -DGL -DFUNCTIONAL -DUSE_POWER_PINS -o gl.vvp \
    "$V/primitives.v" "$V/gf180mcu_fd_sc_mcu7t5v0.v" "$REPO/verilog/gl/chip_core.pnl.v" \
    "$HERE/mtb.sv" > gl_compile.log 2>&1
echo "Running the same 33 gate-level cases..."
timeout 600s vvp -n gl.vvp +N=33 > gl.log 2>&1
python3 "$HERE/check.py" rtl.log gl.log | tee results.txt
# pipefail plus check.py's nonzero failure status prevents copying failed results.
grep '^CASE ' rtl.log > rtl_elements.txt
grep '^CASE ' gl.log > gl_elements.txt
mkdir -p "$HERE/results"
for file in cases.json cases.hex provenance.json check_summary.json results.txt \
    counter.log counter_compile.log rtl.log gl.log rtl_compile.log gl_compile.log \
    rtl_elements.txt gl_elements.txt iverilog_version.txt; do
    cp "$file" "$HERE/results/$file"
done
echo "Fresh passing results saved to $HERE/results"
echo "Working files: $OUT"
echo "REGRESSION PASS: RTL exact cases 23/23; GL vs RTL 33/33"

#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Replay pin-level test vectors on the RTL and, with a PDK path, on the final
# gate-level netlist. Only the chip pins are used (see TEST_PLAN.md). Also runs
# a deliberately wrong vector file, which must be reported as a failure.
# All logs and a summary are kept in a new results folder.
#
#   bash test/run_pin_test.sh [<PDK_ROOT>] [<results dir>]
# Default results dir: test/sim_results/<date-time> (must not exist yet).
# <PDK_ROOT> must contain gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/verilog.
set -euo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)
PDK_ROOT=${1:-}
if [ "$#" -gt 2 ]; then echo 'Usage: bash test/run_pin_test.sh [PDK_ROOT] [results_dir]' >&2; exit 1; fi
if [ -n "$PDK_ROOT" ]; then PDK_ROOT=$(cd "$PDK_ROOT" && pwd); fi
for t in python3 iverilog vvp timeout; do
    command -v "$t" >/dev/null || { echo "Missing $t; enter the project nix-shell" >&2; exit 1; }
done
python3 "$REPO/reproduce/verify_inputs.py" --repo-only
OUT=${2:-$REPO/test/sim_results/$(date +%Y%m%d_%H%M%S)}
[ -e "$OUT" ] && { echo "STOP: $OUT already exists" >&2; exit 1; }
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
cd "$OUT"
SUMMARY=$OUT/SUMMARY.txt
echo "Results and compile logs: $OUT"
trap 's=$?; if [ "$s" -ne 0 ]; then echo "STOP: test failed/incomplete; inspect $OUT" >&2; fi' EXIT
python3 "$REPO/test/record_environment.py" "$OUT" "$PDK_ROOT"

{
    echo "A34 pin-level test run, $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "repository commit: $(git -C "$REPO" rev-parse HEAD 2>/dev/null || echo unknown)"
    echo "uncommitted changes: $(git -C "$REPO" status --porcelain -- src test verilog 2>/dev/null | wc -l) file(s) in src/ test/ verilog/"
    echo "simulator: $(iverilog -V 2>&1 | sed -n '1p')"
    echo "python: $(python3 --version 2>&1)"
    echo "gate-level netlist sha256: $(sha256sum "$REPO/verilog/gl/chip_core.pnl.v" | cut -d' ' -f1)"
} > "$SUMMARY"

python3 "$REPO/test/a34_vectors.py" --selftest | tee -a "$SUMMARY"
python3 "$REPO/test/a34_vectors.py" --identity -o identity.vec
python3 "$REPO/test/a34_vectors.py" --suite -o suite.vec
python3 "$REPO/test/a34_vectors.py" \
    --cases "$REPO/signoff/q16_eco_full4/gl_regression/results/cases.json" -o cases.vec
python3 "$REPO/test/a34_vectors.py" --random 50 --seed 7 -o random.vec
# Deliberate fault: change one expected result nibble in the identity vectors.
python3 - <<'PY'
lines = open('identity.vec').read().split('\n')
for i, line in enumerate(lines):
    f = line.split()
    if len(f) == 4 and f[0] == '1' and f[2] == '1' and f[3] != '0':
        f[3] = format((int(f[3], 16) + 1) % 16, 'x')
        lines[i] = ' '.join(f)
        break
else:
    raise SystemExit('STOP: no expected result found for negative control')
open('fault.vec', 'w').write('\n'.join(lines))
PY
sha256sum ./*.vec >> "$SUMMARY"

run() {  # $1 = label, $2 = simulator image
    for v in identity suite cases random; do
        case "$v" in identity) count=1;; suite) count=9;; cases) count=33;; random) count=50;; esac
        if timeout 20m vvp -n "$2" +VEC=$v.vec +MATRICES=$count > "$1_$v.log" 2>&1 && grep -q '^PIN TEST PASS$' "$1_$v.log"; then
            echo "$1 $v: $(grep '^PIN TEST:' "$1_$v.log")  PASS" | tee -a "$SUMMARY"
        else
            echo "$1 $v: FAIL (see $OUT/$1_$v.log)" | tee -a "$SUMMARY"
            exit 1
        fi
    done
    set +e
    timeout 20m vvp -n "$2" +VEC=fault.vec +MATRICES=1 > "$1_fault.log" 2>&1
    fault_status=$?
    set -e
    if [ "$fault_status" -eq 0 ] || [ "$fault_status" -eq 124 ]; then
        echo "$1 deliberate fault: NOT DETECTED" | tee -a "$SUMMARY"
        exit 1
    fi
    grep -q '^MISMATCH' "$1_fault.log"
    echo "$1 deliberate fault: detected ($(grep -m1 '^MISMATCH' "$1_fault.log"))" | tee -a "$SUMMARY"
}

iverilog -g2012 -s pin_tb -o rtl.vvp "$REPO"/src/rtl/*.v "$REPO"/src/rtl/*.sv \
    "$REPO/src/chipathon_wrapper/chip_core.sv" "$REPO/test/pin_tb.sv" > rtl_compile.log 2>&1
run rtl rtl.vvp

if [ -n "$PDK_ROOT" ]; then
    V=$PDK_ROOT/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/verilog
    echo "cell models: $(sha256sum "$V/primitives.v" "$V/gf180mcu_fd_sc_mcu7t5v0.v" | cut -c1-16 | tr '\n' ' ')" >> "$SUMMARY"
    iverilog -g2012 -s pin_tb -DGL -DFUNCTIONAL -DUSE_POWER_PINS -o gl.vvp \
        "$V/primitives.v" "$V/gf180mcu_fd_sc_mcu7t5v0.v" \
        "$REPO/verilog/gl/chip_core.pnl.v" "$REPO/test/pin_tb.sv" > gl_compile.log 2>&1
    run gl gl.vvp
else
    echo "gate level: not run (no PDK path given)" | tee -a "$SUMMARY"
fi
if [ -n "$PDK_ROOT" ]; then
    echo "PIN REGRESSION PASS: RTL AND GATE LEVEL" | tee -a "$SUMMARY"
else
    echo "PIN REGRESSION PASS: RTL ONLY; GATE LEVEL NOT RUN" | tee -a "$SUMMARY"
fi
echo "Results: $OUT"

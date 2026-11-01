#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Checkpoint-to-GDS replay of the final layout of the corrected design.
# Starts from the committed post-global-routing checkpoint (reproduce/inputs/),
# applies the seven-cell ECO, runs LibreLane from detailed placement to signoff
# with the recorded options, repeats the recorded final-layout checks and
# compares the result with the committed GDS and powered netlist.
# This is NOT a complete RTL-to-GDS rebuild (see reproduce/README.md).
# About one hour.
#
# Run from the repository root inside the project's nix-shell:
#   bash reproduce/replay_eco.sh <PDK_ROOT>
# <PDK_ROOT> contains gf180mcuD/ (the PDK version used for the flow).
set -euo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO"
PDK_ROOT=${1:?usage: bash reproduce/replay_eco.sh <PDK_ROOT>}
PDK_ROOT=$(cd "$PDK_ROOT" && pwd)
TAG=${A34_REPRO_TAG:-A34_REPRO_ECO_$(date +%Y%m%d_%H%M%S)}
case "$TAG" in A34_REPRO_ECO_*) ;; *) echo 'STOP: tag must start A34_REPRO_ECO_' >&2; exit 1;; esac
case "$TAG" in *[!A-Za-z0-9_-]*) echo 'STOP: unsafe run tag' >&2; exit 1;; esac
WORK=$REPO/reproduce/work/$TAG
RUN=$REPO/librelane/runs/$TAG
for d in "$WORK" "$RUN" "$REPO/reproduce/results/$TAG"; do
    [ -e "$d" ] && { echo "STOP: $d already exists; choose a new A34_REPRO_TAG" >&2; exit 1; }
done
for t in librelane openroad python3 gzip sha256sum; do
    command -v "$t" >/dev/null || { echo "Missing $t: run inside nix-shell" >&2; exit 1; }
done
mkdir -p "$WORK"
RESULTS=$REPO/reproduce/results/$TAG
save_results() {  # keep the small logs (not databases) for committing
    status=$?
    mkdir -p "$RESULTS"
    for f in replay.log flow.log apply.log final_odb_check.log compare.txt; do
        [ -f "$WORK/$f" ] && cp "$WORK/$f" "$RESULTS/"
    done
    [ -f "$RUN/final/metrics.json" ] && cp "$RUN/final/metrics.json" "$RESULTS/"
    echo "exit status $status" > "$RESULTS/STATUS"
}
trap save_results EXIT
exec > >(tee "$WORK/replay.log") 2>&1

check() {  # file, expected sha256
    got=$(sha256sum "$1" | cut -d' ' -f1)
    [ "$got" = "$2" ] || { echo "STOP: $1 differs from the recorded version" >&2; exit 1; }
    echo "OK  $1"
}

echo "== 1. Inputs, configuration and PDK files against recorded hashes"
python3 reproduce/verify_inputs.py "$PDK_ROOT"
[ -f reproduce/inputs/SHA256SUMS ] || { echo "STOP: reproduce/inputs/ is missing" >&2; exit 1; }
(cd reproduce/inputs && sha256sum -c SHA256SUMS)
check librelane/chip_core_macro.yaml cbc5d083081c63eaf15fa8e15c6e112cb2289267f22a9b2decc906f73895489e
check librelane/chip_core.sdc 4b75471dd00d5db7fe6a694220f719d6de5578534f8730508c37c4e0f76253b5
LIB=$PDK_ROOT/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/lib
check "$LIB/gf180mcu_fd_sc_mcu7t5v0__tt_025C_5v00.lib" 330aa9439255e3870ad7adfb987cd4d7bcfa7b6f9fb0cd0a712400e9bd80e38a
check "$LIB/gf180mcu_fd_sc_mcu7t5v0__ss_125C_4v50.lib" 4c2657ae12581bc18ed408f3fda0accd10b855118b9993070dbb360dfa3aa874
check "$LIB/gf180mcu_fd_sc_mcu7t5v0__ff_n40C_5v50.lib" 6e04fbedf4279c89a73d6caebe55de27bd760f1aa7c24a4c015489724e4c2439
check "$PDK_ROOT/gf180mcuD/libs.tech/librelane/gf180mcu_fd_sc_mcu7t5v0/pnr_exclude.cells" a46ab41fe9f38cd763051045c11a9bf345e0e26ea7029ae47e510dd7fb1206e3
check gds/chip_core.gds 76091ccb1052a45195f3b30766380e44a60ad4da4ac7ed8a1dac7dec226a87e3
check verilog/gl/chip_core.pnl.v 42821194c1447902f4022622f8daba5143bb3bd526fd32fb5e811a8fcb7a5410
gzip -dc reproduce/inputs/full3_04_resizertimingpostgrt.odb.gz > "$WORK/full3_04.odb"
check "$WORK/full3_04.odb" 3e54c7ed57676d81cf68fc299b20fe22d55d4976286367c27c80e44b2d1d7895
echo "librelane: $(librelane --version 2>&1 | tail -1)"
echo "openroad: $(openroad -version 2>&1 | tail -1)"

echo "== 2. Apply the seven-cell ECO"
A34_LIBERTY=$LIB/gf180mcu_fd_sc_mcu7t5v0__tt_025C_5v00.lib \
A34_ECO_IN_ODB=$WORK/full3_04.odb \
A34_ECO_OUT_ODB=$WORK/chip_core.eco_unlegalized.odb \
    openroad -exit reproduce/apply_seven_cells.tcl > "$WORK/apply.log" 2>&1
cat "$WORK/apply.log" | grep '^A34_' | grep -v '^A34_BOUNDARY'
[ "$(grep -c '^A34_APPLIED ' "$WORK/apply.log")" = 7 ] || { echo "STOP: ECO not applied" >&2; exit 1; }
grep -q '^A34_ECO_COPY_WRITTEN' "$WORK/apply.log"
echo "ECO database sha256: $(sha256sum "$WORK/chip_core.eco_unlegalized.odb" | cut -d' ' -f1)"
if [ -f reproduce/inputs/ORIGINAL_ECO_ODB_SHA256 ]; then
    if [ "$(sha256sum "$WORK/chip_core.eco_unlegalized.odb" | cut -d' ' -f1)" = "$(cat reproduce/inputs/ORIGINAL_ECO_ODB_SHA256)" ]; then
        echo "OK  ECO database identical to the one made on 15 Oct 2026"
    else
        echo "NOTE ECO database bytes differ from the 15 Oct 2026 file; the final comparison decides"
    fi
fi

echo "== 3. Starting state for LibreLane"
python3 - "$WORK" "$REPO/reproduce/inputs" <<'PY'
import json, sys
from pathlib import Path
work, inputs = map(Path, sys.argv[1:])
state = {"json_h": str(inputs / "chip_core.h.json"), "nl": None, "sdf": None,
         "odb": str(work / "chip_core.eco_unlegalized.odb"), "def": None,
         "sdc": None, "pnl": None, "vh": str(inputs / "chip_core.vh"),
         "metrics": {}}
(work / "state_in.json").write_text(json.dumps(state, indent=2) + "\n")
PY

echo "== 4. LibreLane from detailed placement to signoff (run tag $TAG)"
librelane --manual-pdk --pdk gf180mcuD --pdk-root "$PDK_ROOT" \
    --run-tag "$TAG" \
    --from OpenROAD.DetailedPlacement --with-initial-state "$WORK/state_in.json" \
    --skip OpenROAD.CTS --skip OpenROAD.ResizerTimingPostCTS \
    --skip OpenROAD.RepairDesignPostGRT --skip OpenROAD.ResizerTimingPostGRT \
    --skip Odb.DiodesOnPorts --skip Odb.HeuristicDiodeInsertion \
    --override-config RUN_DRT=true --override-config RUN_FILL_INSERTION=true \
    --override-config RUN_ANTENNA_REPAIR=true --override-config RUN_SPEF_EXTRACTION=true \
    --override-config RUN_MCSTA=true --override-config RUN_LVS=true \
    --override-config RUN_MAGIC_STREAMOUT=true --override-config RUN_KLAYOUT_STREAMOUT=true \
    --override-config RUN_MAGIC_DRC=true --override-config RUN_KLAYOUT_DRC=true \
    --override-config "STA_CORNERS=nom_tt_025C_5v00 nom_ss_125C_4v50 nom_ff_n40C_5v50 min_tt_025C_5v00 min_ss_125C_4v50 min_ff_n40C_5v50 max_tt_025C_5v00 max_ss_125C_4v50 max_ff_n40C_5v50" \
    librelane/chip_core_macro.yaml > "$WORK/flow.log" 2>&1 \
    || { tail -40 "$WORK/flow.log"; echo "STOP: LibreLane failed" >&2; exit 1; }
tail -5 "$WORK/flow.log"

echo "== 5. Recorded final-layout checks (ECO cells, boundary, power rings, power grid)"
A34_FINAL_ODB=$RUN/final/odb/chip_core.odb \
    openroad -exit reproduce/check_final_eco.tcl > "$WORK/final_odb_check.log" 2>&1
grep -E '^A34_FINAL_CELL|^A34_POWER|PSM-0040|^A34_FINAL_ODB_CHECK_COMPLETE' "$WORK/final_odb_check.log"
grep -q '^A34_FINAL_ODB_CHECK_COMPLETE' "$WORK/final_odb_check.log" \
    || { echo "STOP: final-layout checks failed" >&2; exit 1; }
[ "$(grep -c 'PSM-0040\] All shapes on net' "$WORK/final_odb_check.log")" = 2 ] \
    || { echo "STOP: power-grid connectivity not confirmed" >&2; exit 1; }
if [ "$(grep '^A34_BOUNDARY' "$WORK/final_odb_check.log")" = "$(grep '^A34_BOUNDARY' signoff/q16_eco_full4/final_odb_check.log)" ]; then
    echo "OK  boundary pins identical to the recorded final check"
else
    echo "STOP: boundary pins differ from the recorded final check" >&2; exit 1
fi

echo "== 6. Compare with the committed layout"
python3 reproduce/compare.py "$RUN" | tee "$WORK/compare.txt"
echo "Logs: $WORK"
echo "Results to commit: reproduce/results/$TAG"

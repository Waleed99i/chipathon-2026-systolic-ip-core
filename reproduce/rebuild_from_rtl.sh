#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# RTL-to-checkpoint rebuild of the corrected design.
#
# Reruns the LibreLane flow from the RTL and librelane/chip_core_macro.yaml the
# way the recorded runs did (reproduce/records/), and checks that the result is
# byte-identical to checkpoint B, the committed starting point of the
# checkpoint-to-GDS replay (reproduce/inputs/, sha256 3e54c7ed...).
# If it is, this script plus replay_eco.sh reproduce the complete RTL-to-GDS
# sequence from the repository.
#
# Recorded sequence:
#   FULL2  flow from the RTL with GRT_DESIGN_REPAIR_MAX_SLEW_PCT = 40;
#          steps 01-40 completed (40 = OpenROAD.CheckAntennas after global
#          routing), step 41 was interrupted
#   FULL3  resumed at OpenROAD.RepairDesignPostGRT with the committed YAML
#          (GRT_DESIGN_REPAIR_MAX_SLEW_PCT = 30, the only setting that differs)
#   Checkpoint B = FULL3 step 04 (OpenROAD.ResizerTimingPostGRT)
#
# Run from the repository root inside the project's nix-shell:
#   bash reproduce/rebuild_from_rtl.sh <PDK_ROOT>
set -euo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO"
PDK_ROOT=${1:?usage: bash reproduce/rebuild_from_rtl.sh <PDK_ROOT>}
PDK_ROOT=$(cd "$PDK_ROOT" && pwd)
STAMP=$(date +%Y%m%d_%H%M%S)
TAG=A34_REBUILD_$STAMP
T1=${TAG}_STAGE1
T2=${TAG}_STAGE2
RESULTS=$REPO/reproduce/results/$TAG
CHECKPOINT_SHA=3e54c7ed57676d81cf68fc299b20fe22d55d4976286367c27c80e44b2d1d7895
for d in "librelane/runs/$T1" "librelane/runs/$T2" "$RESULTS"; do
    [ -e "$d" ] && { echo "STOP: $d already exists" >&2; exit 1; }
done
for t in librelane openroad python3 gzip sha256sum; do
    command -v "$t" >/dev/null || { echo "Missing $t: run inside nix-shell" >&2; exit 1; }
done
mkdir -p "$RESULTS"
exec > >(tee "$RESULTS/rebuild.log") 2>&1
finish() {
    status=$?
    echo "exit status $status" > "$RESULTS/STATUS"
}
trap finish EXIT

echo "== 1. Inputs, tools and key PDK files against recorded hashes"
python3 reproduce/verify_inputs.py "$PDK_ROOT"
echo "librelane: $(librelane --version 2>&1 | tail -1)"
echo "openroad: $(openroad -version 2>&1 | tail -1)"
echo "commit: $(git rev-parse HEAD 2>/dev/null || echo unknown)"

COMMON=(--manual-pdk --pdk gf180mcuD --pdk-root "$PDK_ROOT")

echo "== 2. Stage 1 (as FULL2): RTL to the antenna check after global routing"
librelane "${COMMON[@]}" --run-tag "$T1" \
    --override-config GRT_DESIGN_REPAIR_MAX_SLEW_PCT=40 \
    --to OpenROAD.CheckAntennas \
    librelane/chip_core_macro.yaml > "$RESULTS/stage1_flow.log" 2>&1 \
    || { tail -40 "$RESULTS/stage1_flow.log"; echo "STOP: stage 1 failed" >&2; exit 1; }
S1=librelane/runs/$T1/40-openroad-checkantennas
[ -f "$S1/state_out.json" ] || { echo "STOP: $S1/state_out.json missing" >&2; exit 1; }

echo "== 3. Stage 2 (as FULL3): post-global-route repair to timing repair"
librelane "${COMMON[@]}" --run-tag "$T2" \
    --from OpenROAD.RepairDesignPostGRT --to OpenROAD.ResizerTimingPostGRT \
    --with-initial-state "$S1/state_out.json" \
    librelane/chip_core_macro.yaml > "$RESULTS/stage2_flow.log" 2>&1 \
    || { tail -40 "$RESULTS/stage2_flow.log"; echo "STOP: stage 2 failed" >&2; exit 1; }
B=librelane/runs/$T2/04-openroad-resizertimingpostgrt/chip_core.odb
[ -f "$B" ] || { echo "STOP: $B missing" >&2; exit 1; }

echo "== 4. Steps and settings against the run records"
python3 reproduce/compare_records.py "$REPO" "$PDK_ROOT" "librelane/runs/$T1" "librelane/runs/$T2" \
    | tee "$RESULTS/records_check.txt"

echo "== 5. Compare with checkpoint B"
GOT=$(sha256sum "$B" | cut -d' ' -f1)
echo "rebuilt checkpoint: $B"
echo "sha256 $GOT"
if [ "$GOT" = "$CHECKPOINT_SHA" ]; then
    echo "REBUILT: identical to checkpoint B (reproduce/inputs/full3_04_resizertimingpostgrt.odb.gz)" \
        | tee "$RESULTS/result.txt"
    echo "Together with replay_eco.sh this reproduces the complete RTL-to-GDS sequence."
    echo "Results to commit: reproduce/results/$TAG"
    exit 0
fi
echo "DIFFERENT: rebuilt checkpoint is not byte-identical to checkpoint B" | tee "$RESULTS/result.txt"
echo "== 6. Structural comparison (diagnosis)"
WORK=$REPO/reproduce/work/$TAG
mkdir -p "$WORK"
gzip -dc reproduce/inputs/full3_04_resizertimingpostgrt.odb.gz > "$WORK/checkpoint_b.odb"
A34_DUMP_ODB=$WORK/checkpoint_b.odb A34_DUMP_OUT=$WORK/checkpoint_b.txt \
    openroad -exit reproduce/dump_odb.tcl > "$WORK/dump_b.log" 2>&1
A34_DUMP_ODB=$B A34_DUMP_OUT=$WORK/rebuilt.txt \
    openroad -exit reproduce/dump_odb.tcl > "$WORK/dump_rebuilt.log" 2>&1
python3 reproduce/compare_dumps.py "$WORK/checkpoint_b.txt" "$WORK/rebuilt.txt" \
    | tee -a "$RESULTS/result.txt"
echo "Results to commit: reproduce/results/$TAG"
exit 1

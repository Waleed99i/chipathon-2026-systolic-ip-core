#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# One-time step for the team member who holds the original runs.
# Copies the three ECO starting inputs out of the local FULL2/FULL3 runs into
# reproduce/inputs/, compresses the checkpoint reproducibly and records hashes.
# Refuses to overwrite an existing reproduce/inputs/ folder.
#
#   bash reproduce/collect_inputs.sh
set -euo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO"
RUNS=librelane/runs
ODB=$RUNS/A34_Q16_FIX_FULL3/04-openroad-resizertimingpostgrt/chip_core.odb
JSONH=$RUNS/A34_Q16_FIX_FULL2/05-yosys-jsonheader/chip_core.h.json
VH=$RUNS/A34_Q16_FIX_FULL2/29-odb-writeverilogheader/chip_core.vh
ODB_SHA=3e54c7ed57676d81cf68fc299b20fe22d55d4976286367c27c80e44b2d1d7895
ORIG_ECO=verification_results/physical-eco-yoy1al0x/chip_core.eco_unlegalized.odb

[ -e reproduce/inputs ] && { echo "STOP: reproduce/inputs already exists; not overwriting" >&2; exit 1; }
for f in "$ODB" "$JSONH" "$VH"; do
    [ -f "$f" ] || { echo "STOP: missing $f" >&2; exit 1; }
done
got=$(sha256sum "$ODB" | cut -d' ' -f1)
[ "$got" = "$ODB_SHA" ] || { echo "STOP: FULL3 checkpoint hash $got differs from the recorded $ODB_SHA" >&2; exit 1; }

mkdir reproduce/inputs
gzip -9 -n -c "$ODB" > reproduce/inputs/full3_04_resizertimingpostgrt.odb.gz
cp "$JSONH" reproduce/inputs/chip_core.h.json
cp "$VH" reproduce/inputs/chip_core.vh
if [ -f "$ORIG_ECO" ]; then
    sha256sum "$ORIG_ECO" | cut -d' ' -f1 > reproduce/inputs/ORIGINAL_ECO_ODB_SHA256
fi
(
    cd reproduce/inputs
    sha256sum full3_04_resizertimingpostgrt.odb.gz chip_core.h.json chip_core.vh > SHA256SUMS
)
ls -la reproduce/inputs
echo "Checkpoint matches the recorded hash. Inputs written to reproduce/inputs/."

# Reproducing the final layout (corrected design)

**Status (1 November 2026): the final layout is reproduced from the RTL.**

- **RTL-to-checkpoint rebuild PASSED** (`A34_REBUILD_20261101_172831`): starting from the RTL and the committed YAML, the rebuilt post-global-route checkpoint is byte-identical to checkpoint B (sha256 `3e54c7ed…`).
- **Checkpoint-to-GDS replay PASSED** (`A34_REPRO_ECO_20261031_100206`): from checkpoint B, the seven-cell ECO and the rest of the flow reproduce the committed powered netlist byte-for-byte and the committed GDS in every polygon and label, with all signoff checks clean.

Because the rebuilt checkpoint is the same file that the replay starts from, the two runs together cover the complete sequence from RTL to GDS.

## RTL-to-checkpoint rebuild result (1 November 2026)

Run `A34_REBUILD_20261101_172831` ran in a fresh clone of `main` (commit `aba0ac9`) with the scripts in this folder added, using the project's nix-shell (LibreLane 3.0.0, OpenROAD `dcf36133…`) and the local `gf180mcuD` PDK. Results are in `reproduce/results/A34_REBUILD_20261101_172831/`:

- Recorded inputs, tool versions and key PDK files: check passed.
- Stage 1 ran the same 40 steps as FULL2 and stage 2 the same 4 steps as FULL3; all 411 resolved settings of each stage (every entry except the run metadata) matched the run records (`records_check.txt`).
- The rebuilt checkpoint (stage 2, step 04) was byte-identical to `reproduce/inputs/full3_04_resizertimingpostgrt.odb.gz` (`result.txt`).

The rebuild used the same computer, Nix environment and PDK installation as the original runs; a separate tool or PDK installation has not been tested.

## Checkpoint-to-GDS replay result (31 October 2026)

Run `A34_REPRO_ECO_20261031_100206` completed in a separate local clone, using the existing Nix environment and local PDK. The new replay helpers and checkpoint inputs were copied into that clone before execution. This verifies checkpoint replay in another directory, not yet an independent download-and-build from the published repository or a fresh tool/PDK installation.

Results are saved in `reproduce/results/A34_REPRO_ECO_20261031_100206/`:

- The seven-cell ECO recreated the recorded pre-routing ECO database byte-for-byte.
- Final cell, boundary-pin and power-grid connectivity checks passed.
- All 23 checked aggregate signoff counts were zero; setup, hold, slew, capacitance and fanout violation counts were zero across all nine corners, with non-negative worst slack.
- Worst setup slack: 0.5498535116 ns. Worst hold slack: 0.0911544199 ns.
- The powered netlist was byte-identical to the committed reference.
- GDS file bytes differed, but polygon geometry and labels matched across all 27 layers. Top cell, database unit and 1675 x 1675 um boundary matched.

This is block-level evidence under the recorded constraints and checks. It does not establish integrated-chip signoff, pad-aware IR/EM signoff, silicon operation, or organizer acceptance. See the saved flow log for warnings.

The uploaded FULL2/FULL3 resolved configurations were compared (412 entries).
Their only difference is GRT slew-repair margin: 40% in FULL2, 30% in FULL3.
Both retain the 45 ns clock, 180 µm CTS buffer distance, 0.2 ns GRT setup margin
and 30% capacitance-repair margin. See `run_settings_review.json` for evidence.
The rebuild of 1 November 2026 repeats exactly this sequence and confirms it (see above).

## What was built, and what this folder reproduces

The committed layout is `gds/chip_core.gds` (sha256 `76091ccb…`), with the powered netlist `verilog/gl/chip_core.pnl.v` (sha256 `42821194…`). It was produced in this sequence:

```
A  LibreLane flow from librelane/chip_core_macro.yaml   (run FULL2, then FULL3 resumed after global routing)
B  checkpoint after post-global-route timing repair     (FULL3 step 04)
C  seven-cell ECO: 3 logic cells up-sized, 4 clock leaf buffers down-sized
D  LibreLane from detailed placement through routing, extraction, STA, DRC and LVS   (run FULL4)
```

| Level | Covers | Status |
|---|---|---|
| **Checkpoint-to-GDS replay** | C and D, starting from checkpoint B in `reproduce/inputs/` | **PASSED**: `A34_REPRO_ECO_20261031_100206` |
| **RTL-to-checkpoint rebuild** | A and B, starting from the RTL and YAML | **PASSED**: `A34_REBUILD_20261101_172831` (`rebuild_from_rtl.sh`) |

The YAML alone does not replay the ECO, and the flow was run in two parts with one setting changed in between. Running `rebuild_from_rtl.sh` and then `replay_eco.sh` repeats the complete sequence.

## RTL-to-checkpoint rebuild (about one hour)

```bash
nix-shell
bash reproduce/rebuild_from_rtl.sh <PDK_ROOT>
```

1. **Check inputs** with `verify_inputs.py`: RTL, YAML, SDC, flake, LibreLane and OpenROAD versions, key PDK files.
2. **Stage 1 (as FULL2):** the flow from the RTL to `OpenROAD.CheckAntennas` after global routing, with `GRT_DESIGN_REPAIR_MAX_SLEW_PCT=40`.
3. **Stage 2 (as FULL3):** from the stage 1 state, `OpenROAD.RepairDesignPostGRT` to `OpenROAD.ResizerTimingPostGRT` with the committed YAML (30).
4. **Compare with the run records** (`compare_records.py`, `records/`): step lists and every resolved setting, with the original machine's paths mapped to this clone and PDK.
5. **Compare with checkpoint B:** `REBUILT` if the database is byte-identical. Otherwise `DIFFERENT`, followed by an instance-level comparison (`dump_odb.tcl`, `compare_dumps.py`) for diagnosis.

Runs go to `librelane/runs/A34_REBUILD_<date>_STAGE1|STAGE2/`; logs and results to `reproduce/results/A34_REBUILD_<date>/`.

## Checkpoint-to-GDS replay (about one hour)

Requirements:
- the project's nix-shell (LibreLane, OpenROAD, KLayout Python module, Python 3)
- the GF180MCU PDK `gf180mcuD` used for the flow. The script checks the timing libraries and the cell exclusion list against the hashes recorded for the final run.

```bash
nix-shell
bash reproduce/replay_eco.sh <PDK_ROOT>
```

Steps in the script:
1. **Check inputs.** The committed inputs, `chip_core_macro.yaml`, `chip_core.sdc`, the PDK timing libraries, `pnr_exclude.cells` and the committed reference GDS and netlist must all match their recorded hashes.
   Revision 3 also checks recorded RTL/flake hashes, LibreLane 3.0.0 and the
   recorded OpenROAD commit. These checks cover key PDK inputs, not every PDK
   file; exact PDK provenance/local modifications still need documentation.
2. **Apply the ECO.** The seven cell changes are applied with `apply_seven_cells.tcl`. It has the same logic as `signoff/q16_eco_full4/apply_seven_cells.tcl`; only the file paths are passed in.
3. **Run LibreLane** from `OpenROAD.DetailedPlacement` with the options recorded in `signoff/q16_eco_full4/eco_run_manifest.json`.
4. **Repeat the recorded final-layout checks** with `check_final_eco.tcl`:
   - the seven final cells
   - boundary pins identical to the recorded check
   - Metal2 power terminals and the Metal4/Metal5 ring on VDD and VSS
   - OpenROAD power-grid connectivity
5. **Compare with the committed layout** (`compare.py`):
   - all signoff counts zero, in total and in each of the nine corners
   - non-negative worst slack in every corner
   - powered netlist byte-identical
   - GDS top cell, database unit and boundary
   - the GDS either byte-identical, or identical in every polygon and every text label on all layers. In the second case the result says that the file bytes differ.

The script refuses to reuse an existing run tag. Working files go to `reproduce/work/<tag>/` (not committed) and the run to `librelane/runs/<tag>/`. The logs and final metrics are copied to `reproduce/results/<tag>/` for committing.

## Run records (`reproduce/records/`)

`FULL2_resolved.json`, `FULL3_resolved.json`: the resolved LibreLane settings of the two original runs. `FULL2_steps.txt`, `FULL3_steps.txt`: their step lists.

## Inputs (`reproduce/inputs/`)

| File | Origin |
|---|---|
| `full3_04_resizertimingpostgrt.odb.gz` | Checkpoint B (uncompressed sha256 `3e54c7ed…`, as recorded in the ECO manifest) |
| `chip_core.h.json`, `chip_core.vh` | Design headers from the FULL2 synthesis and floorplan steps, used by the recorded ECO run |
| `ORIGINAL_ECO_ODB_SHA256` | Hash of the ECO database made on 15 Oct 2026, for comparison |
| `SHA256SUMS` | Hashes of the input files |

These files were collected from the original runs with `collect_inputs.sh` and are included in `reproduce/inputs/` for publication with the replay scripts. The collector refuses to overwrite an existing folder. Reviewers use the supplied checkpoint and headers; the matching tools and PDK are still external prerequisites.

## Running both in a fresh clone

Use a **fresh clone**, not a working copy that holds the original runs. This tests that the published design inputs are sufficient; the required tools and PDK remain external:

```bash
git clone https://github.com/Waleed99i/chipathon-2026-systolic-ip-core.git a34-check
cd a34-check
nix-shell
bash reproduce/rebuild_from_rtl.sh <PDK_ROOT>
bash reproduce/replay_eco.sh <PDK_ROOT>
```

Publish the actual results (`reproduce/results/<tag>/`) whether or not they match.

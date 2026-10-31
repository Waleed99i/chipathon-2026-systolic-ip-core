# Reproducing the final layout (corrected design)

**Status (31 October 2026): checkpoint-to-GDS replay PASSED. A fresh complete RTL-to-GDS rebuild remains PENDING.**

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
This is configuration evidence, not proof of a successful clean rebuild.

The proposed reconstruction is: run the FULL2 settings through global routing
under a fresh tag; resume from that saved state at post-GRT design repair with
FULL3's 30% margin; stop after post-GRT timing repair and compare its ODB with
the historical checkpoint hash. Exact tested commands and results remain pending.
Do not assume new synthesis preserves instance names or byte-identical ODBs.

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
| **Complete RTL-to-GDS rebuild** | A to D, starting from the RTL and YAML | **PENDING**: the FULL2 and FULL3 commands will be added from the run records |

The YAML alone does not replay the ECO. The checkpoint replay is therefore the step that a reviewer could not repeat before. It is not yet a complete rebuild from RTL.

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

## Inputs (`reproduce/inputs/`)

| File | Origin |
|---|---|
| `full3_04_resizertimingpostgrt.odb.gz` | Checkpoint B (uncompressed sha256 `3e54c7ed…`, as recorded in the ECO manifest) |
| `chip_core.h.json`, `chip_core.vh` | Design headers from the FULL2 synthesis and floorplan steps, used by the recorded ECO run |
| `ORIGINAL_ECO_ODB_SHA256` | Hash of the ECO database made on 15 Oct 2026, for comparison |
| `SHA256SUMS` | Hashes of the input files |

These files were collected from the original runs with `collect_inputs.sh` and are included in `reproduce/inputs/` for publication with the replay scripts. The collector refuses to overwrite an existing folder. Reviewers use the supplied checkpoint and headers; the matching tools and PDK are still external prerequisites.

## Validating the replay

After the replay scripts, inputs and evidence are committed and pushed, run the replay in a **fresh clone**, not in the working copy that holds the original runs. This tests that the published design inputs are sufficient; the required tools and PDK remain external:

```bash
git clone --branch a34-rtl-fix-pd <repository> /tmp/a34-replay-check
cd /tmp/a34-replay-check
nix-shell
bash reproduce/replay_eco.sh <PDK_ROOT>
```

Publish the actual results (`reproduce/results/<tag>/`) whether or not they match.

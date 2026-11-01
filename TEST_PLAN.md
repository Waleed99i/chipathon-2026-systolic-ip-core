# Silicon test plan: A34 SiliconForge systolic accelerator (GF180MCU)

IEEE SSCS PICO Chipathon 2026, Team A34 SiliconForge.
**Verification status (31 October 2026): pin-only RTL and gate-level regression PASSED.**
The cycle schedule below passed the tested vector sets on both implementations.
Checkpoint-to-GDS replay also PASSED; see `reproduce/README.md` for results and scope.
These are pre-silicon results, not silicon measurements or integrated-chip approval.
This plan covers the corrected design on branch `a34-rtl-fix-pd` (final layout and powered netlist in `gds/` and `verilog/gl/`).
Items marked **PENDING** depend on the package, carrier board or padframe that the organizers have not yet finalized. They will be filled in when that information is available.

## 1. Goal

The chip computes C = A·B for two 4×4 matrices of FP16 numbers, using an approximate logarithmic multiplier and 32-bit Q16.16 accumulation. The silicon tests answer four questions:

1. Does the chip power up and reset safely?
2. Is every result **bit-for-bit equal** to what the design specifies? This is the pass/fail test. The reference is `test/a34_vectors.py`, a model of the implemented approximate arithmetic that matches the RTL and the final gate-level netlist.
3. Does it work at the design clock of **22.2 MHz (45 ns)** across the supply range, and where are the limits?
4. How much supply current does it draw, idle and computing?

**How accurate the approximate arithmetic is compared with exact mathematics** is reported separately (Section 8). It does not decide pass/fail, because the approximation is intended.

## 2. Who tests, where, and with what

| Item | Plan |
|---|---|
| Chip recipient and test lead | Proposed: Rumali Siddiqua (USA). **PENDING**: confirm with the organizers who receives the chips. Other team members review results and help with analysis. |
| Test location | **PENDING**: lab or bench access to be confirmed before chips arrive |
| Bench supply | Required: programmable supply with adjustable current limit and current readout. **PENDING**: confirm access |
| Pattern generator and capture | Required: FPGA board or microcontroller that replays the vector files, with at least 10 outputs (clock, reset, 8 data) and 4 inputs, and a clock output of at least 25 MHz. **PENDING**: confirm which board is available |
| Level translation | Required if the controller's I/O voltage differs from the chip I/O voltage (see Section 3) |
| Measurement | Oscilloscope for clock, reset and output edges; multimeter for supply current |
| Host | PC with Python 3 for vector generation and result comparison |

## 3. Package, board and connections

| Item | Status |
|---|---|
| Package type and pin numbering | **PENDING** (organizers' packaging decision) |
| Carrier/test board and connector pinout | **PENDING** |
| Chip I/O voltage and logic thresholds | **PENDING** (padframe). The core standard cells are characterized for 4.5–5.5 V. |
| Clock input | Driven from the pattern generator, at the chip I/O voltage |
| Reset input | `rst_n` (Schmitt input) driven from the pattern generator |
| Unused bidirectional-pad inputs | Not used by the design; the pads are always driven as outputs |

Once the package and board are known, a connection table (chip pin → package pin → board connector → controller pin) will be added here.

**Block pins used by the test:**

| Pin | Direction | Use |
|---|---|---|
| `VDD`, `VSS` | supply | Core supply |
| `clk` | input | System clock, design target 22.2 MHz |
| `rst_n` | input | Active-low reset; **reset before every matrix** |
| `input_in[7:0]` | input | Input byte |
| `output_out[3:0]` | output | Result nibble |

There are **no ready/valid pins**. The design is fully synchronous and its timing does not depend on the data, so the tester drives and samples the pins on fixed clock cycles (Section 4).

## 4. Loading matrices and reading results (pin protocol)

Count rising clock edges from reset release: **edge 0 is the first rising edge with `rst_n = 1`**. Hold `rst_n = 0` for at least 4 rising edges before that, with the clock running.

| Step | Rising edges | What happens |
|---|---|---|
| Packet 0 input | 0–15 | One byte captured per edge |
| Packet 1 input | 18–33 | Bytes on edges 16–17 are ignored |
| Packet 2 input | 36–51 | |
| Packet 3 input | 54–69 | |
| Computation | 70–125 | Inputs are don't-care; outputs read 0 |
| Output nibble *j* (j = 0…127) | on the pins after rising edge 126+2j until rising edge 128+2j | Read at the falling edges after rising edges 126+2j and 127+2j: both give nibble *j* |
| After nibble 127 | from rising edge 382 | Outputs read 0 |

In reset (from the second rising edge with `rst_n = 0`) and after edges 0–125, the outputs read 0.

The generated test covers **386 clock cycles** after reset (edges 0–385), plus four reset cycles: 390 total. At a 45 ns period, the active portion takes 17.370 µs. Then reset again for the next matrix.

**Input data.** Packet *p* (p = 0…3) is 16 bytes: row *p* of A (A[p][0..3]) followed by column *p* of B (B[0..3][p]), each value a 16-bit FP16 word, most significant byte first.

**Output data.** 16 results, row-major (C[0][0], C[0][1], …, C[3][3]). Each is a 32-bit two's-complement Q16.16 value sent as 8 nibbles, most significant first.

**Example (A = 1…16 row by row, B = identity, so C = A).**
Packet 0 bytes: `3c 00 40 00 42 00 44 00 3c 00 00 00 00 00 00 00` (1, 2, 3, 4, then column 0 of B = 1, 0, 0, 0).
First output nibbles: `0001 0000` = 0x00010000 = 1.0, then `0002 0000` = 2.0, and so on.

`test/a34_vectors.py` writes this timing as a vector file with one line per rising edge (`rst_n input_byte check expected_pins`), including the reset before each matrix. **Every output sample is checked** except the first reset edge, whose value before any clock edge is undefined:
- the zeros in reset and before the result
- both samples of every nibble
- the return to zero afterwards

The tester only has to replay the file and compare.

## 5. Safe power-up and current measurement

1. With the chip unpowered, set the bench supply to 0 V and set a low current limit (**PENDING**: value after package and board are known).
2. Hold the controller outputs low, so no input is driven above VDD before VDD is up.
3. Raise VDD to nominal (**PENDING**: nominal I/O and core voltages from the organizers). Record current with the clock stopped and `rst_n = 0`.
4. Start the clock at 1 MHz, keep `rst_n = 0`, and record current again.
5. Stop and investigate if any of these happens:
   - the supply reaches its current limit
   - the current does not settle or keeps rising
   - the package warms noticeably

   Current limits and stop thresholds come from the organizers' package and board data (**PENDING**). The vectorless power estimate in the notebook is recorded only for comparison and is not a safety criterion.

## 6. Test sequence

Run on every chip. Record chip ID, VDD, clock frequency, room temperature and the result. Each matrix is preceded by a reset.

| ID | Test | Vectors | Conditions | Pass criterion |
|---|---|---|---|---|
| T1 | Power-up and idle current | none | Section 5 | No abnormal current; values recorded |
| T2 | Reset and idle outputs | any | 1 MHz | Outputs read 0 in reset and after edges 0–125 (checked in every vector file) |
| T3 | Bring-up suite | `--suite` | 1 MHz, nominal VDD | All nibbles match |
| T4 | Full functional | 33 regression matrices (`--cases`) + 1,000 random (`--random 1000`) | 1 MHz, nominal VDD | All nibbles match |
| T5 | Design clock | T3 + T4 | 22.2 MHz, nominal VDD | All nibbles match |
| T6 | Frequency limit | T3 | Raise the clock from 22.2 MHz in steps until the first mismatch | Characterization: record the highest passing frequency |
| T7 | Supply sweep (shmoo) | T3 | VDD low / nominal / high × frequencies from T6 (**PENDING**: allowed range) | Characterization: pass/fail map; target is pass at 22.2 MHz across the allowed range |
| T8 | Operating current | T4, looped | 1 MHz and 22.2 MHz | Record values |
| T9 | Repeatability | T5 | Three times per chip, all available chips | Same results each time |

**Bring-up suite (`--suite`), each with its own reset:**

| Matrix | Expected result | What it checks |
|---|---|---|
| zero × zero | all 0 | Clean reset, no stuck bits |
| A × identity, identity × B | C = A, C = B | Data paths, operand order |
| all-ones × all-ones | every element 4.0 | Accumulation across all four products |
| signed matrix × A | mixed negative and positive results | Sign handling |
| A × (−identity) | C = −A | Negative results |
| all-64 matrix × 4·identity | every element 256.0 | Values above the old Q8.8 maximum (+127.996) |
| 127·identity × 256·identity | 32512 on the diagonal | Close to the Q16.16 maximum (+32767.99998) |
| all-64 matrix × all-128 matrix | every element −32768 | Documented Q16.16 wrap-around (4 × 8192 = 32768 exceeds the range) |

The 33 regression matrices include more exact-arithmetic cases (powers of two up to ±32) and general FP16 values. The random set uses values in ±6.

## 7. Pass/fail

A chip **passes** if T1–T5 and the repeatability test T9 pass. T6–T8 are characterization and are reported as measured. The pattern generator must meet input/output timing requirements; a 25 MHz clock output alone does not establish this capability.

## 8. Accuracy report (separate from pass/fail)

For every matrix, the host-side comparison will also compare the chip's results with exact matrix multiplication of the same FP16 inputs and report:
- the maximum absolute error divided by the largest |A·B| element,
- the same statistics as the notebook's MAC accuracy section, so silicon and simulation can be compared directly.

Exact-arithmetic cases should match mathematics only when the multiplier's supported FP16 behavior, converter precision/range and accumulator range all permit exact results. Exclude underflow, quantization, saturation and intentional wraparound from that claim. If the exact matrix is all zero, report absolute error rather than divide by a zero normalization denominator.

## 9. If a test fails

1. Repeat at 1 MHz to separate timing failures from functional ones.
2. Check reset timing and the edge numbering of Section 4 with the oscilloscope.
3. Compare captured and expected nibbles. Find the first wrong element and whether the error is in one output bit, one array position (row/column) or all results.
4. Replay the same vectors in gate-level simulation (`test/run_pin_test.sh <PDK_ROOT>`) for comparison.

## 10. Publishing results

Results go in `test/results/<chip-id>/`:
- test conditions (VDD, frequency, temperature, board, equipment),
- vector files used and the captured outputs for every run,
- pass/fail summary for T1–T9, the frequency/supply shmoo and current measurements,
- the accuracy report and any failure analysis.

A summary table will be added to the repository README.

## 11. Pre-silicon verification of this plan

The protocol in Section 4 was tested by `test/pin_tb.sv`, which uses **only the chip pins** (no internal signals), as a tester would. The fresh run `20261031_095426` passed every vector set below on both the RTL and the final gate-level netlist `verilog/gl/chip_core.pnl.v` (sha256 `42821194…`), with zero mismatches. Re-run with `bash test/run_pin_test.sh <PDK_ROOT>`:

| Vector set | Matrices | Output samples checked |
|---|---|---|
| identity | 1 | 389 |
| bring-up suite | 9 | 3,501 |
| regression | 33 | 12,837 |
| random (seed 7) | 50 | 19,450 |

The four sets total 93 matrix transactions and 36,177 checked output samples per implementation; sets may overlap and are not claimed to be 93 unique matrices. Both RTL and gate-level negative-control runs detected the deliberately wrong vector. Each matrix contains 390 vector rows and 389 checked samples; missing cases fail. Logs, vectors, `SUMMARY.txt` and input/tool hashes in `provenance.json` are retained under `test/sim_results/20261031_095426/`. Compiled `.vvp` executables are excluded from Git and regenerated by the test script.

The reference model in `test/a34_vectors.py` reproduces all 528 result words of the recorded 33-case RTL and gate-level regression. Simulation is zero-delay; timing is covered by the nine-corner static timing analysis.

## 12. Known limitations

- One matrix per reset; there is no handshake, so the tester must follow the fixed timing in Section 4.
- Sums outside the Q16.16 range (±32768) wrap around. The model includes this, so bit-exact comparison still applies.
- The design has been verified in simulation and static timing analysis only; these tests are the first silicon measurements.

## Files

| File | Purpose |
|---|---|
| `TEST_PLAN.md` | This plan |
| `test/a34_vectors.py` | Reference model and vector generator (Python standard library only) |
| `test/pin_tb.sv` | Pin-only testbench that replays a vector file |
| `test/run_pin_test.sh` | Runs the vectors on RTL and, with a PDK path, on the final gate-level netlist |
| `test/sim_results/<date>/` | Logs and summary of a pin-level test run |
| `reproduce/` | Checkpoint-to-GDS replay of the final layout (see `reproduce/README.md`) |

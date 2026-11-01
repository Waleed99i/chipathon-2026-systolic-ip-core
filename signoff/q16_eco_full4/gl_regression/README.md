# Gate-level matrix regression of the final ECO netlist

This is an additional **test-only** check of the implementation first committed at
`c98ec31ebb989d6eafee9f8927985622fc515526`. It does not change the implemented RTL,
GDS, powered netlist, SDC, PD configuration or ECO cell choices.

The runner checks the final netlist SHA-256
`42821194c1447902f4022622f8daba5143bb3bd526fd32fb5e811a8fcb7a5410`, the GDS hash
and the recorded RTL hashes before simulation. It records simulation-model and
test-file hashes as provenance. Changed testbench files are intentionally allowed.

## Cases and pass criteria

- 23 exact-arithmetic cases: identity, all-ones, a permutation, and 20 deterministic
  random signed power-of-two matrices. All 16 RTL Q16.16 words must equal the
  representable mathematical reference **bit for bit**, without floating tolerance.
- 10 general FP16-input cases: all 16 gate-level words must equal RTL bit for bit.
  Approximation error is reported as `max(abs(result-reference))/max(abs(reference))`
  per matrix. This is not per-element relative error and is not a universal bound.
- Every case must have exactly 16 known words and one completion record. Missing,
  duplicate, unknown (X/Z), timed-out and mismatching results fail with a nonzero exit.
- The counter unit test checks two 10-step bursts, the intervening wrap event,
  idle-cycle clearing and reset. The matrix harness has a 600 us simulation timeout;
  each simulator invocation also has a 600 s wall-clock timeout.

Simulation uses zero-delay `FUNCTIONAL` standard-cell models with explicit supplies
and no SDF. Its 10 ns testbench clock is a functional stimulus, not a timing-closure
claim. The existing extracted nine-corner STA covers the 45 ns implementation target.
Packets use internal handshake nets; this is not a pin-only software/board protocol
validation. Each matrix starts with reset. This finite sampled check is not formal
equivalence, an exhaustive accelerator test, or silicon validation.

## Run and evidence

From the project nix-shell (Icarus Verilog, Python 3, NumPy and GNU timeout):

```bash
bash signoff/q16_eco_full4/gl_regression/run_gl_regression.sh \
  ~/openlane_project/chipathon-2026-systolic-ip-core-main-git/gf180mcu
```

Accept the run only if it exits zero and prints `REGRESSION PASS`. Fresh logs,
cases, summaries and provenance are copied to `results/` only after all checks
pass. Raw simulation files remain under `verification_results/gl-regression-*`.
A failed rerun leaves any prior passing `results/` intact: inspect the current
exit status and the new diagnostic directory, not an old results file.

No pre-recorded passing results are supplied by this reviewed patch. The submitted
patch's original element transcripts passed independent arithmetic/data comparison,
but this patch requires a fresh run against the final netlist on the PD machine.

To collect implementation history without editing design files:

```bash
python3 signoff/q16_eco_full4/gl_regression/collect_run_history.py
```

Run history is read from actual per-step configuration and metrics files. Aborted
runs are explicitly shown without final results. A resumed run's per-step settings
do not establish the settings of earlier inherited steps; checkpoint references
are printed to identify that dependency.

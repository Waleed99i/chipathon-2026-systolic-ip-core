# A34 corrected-RTL candidate: local ECO signoff

Run: `A34_Q16_ECO_FULL4_20261015_160735`. Clock target: 45 ns.

All nine corners report zero setup, hold, slew, capacitance and fanout violations.
Worst setup slack: +0.549854 ns; worst hold slack: +0.091154 ns.
Routing/Magic/KLayout DRC, LVS and antenna checks pass. Final power connectivity
and boundary/ring checks pass. See detailed reports and recorded artifact hashes.

This layout includes seven explicit cell-master changes followed by legalization,
rerouting, new extraction and signoff. YAML alone does not replay that ECO.
The archived scripts and checkpoint records contain the original absolute paths.
The separate preservation bundle includes the pre/post-ECO ODB and required headers.
Keep FULL2, FULL3, FULL4 and diagnostics until relocation/reproduction is arranged.

The powered netlist in verilog/gl and GDS in gds belong to this same final run.
Earlier general signoff directories may describe the prior implementation;
this directory and the updated signoff/lvs files are this candidate's evidence.

Functional regression evidence is copied without rerunning the tests. It covers
65,536 converter encodings and 22 wrapper cases (20 exact, two approximate-model).
Reset per matrix, approximate arithmetic, continuing internal activity and finite
Q16.16/accumulator range remain limitations. No formal RTL equivalence was run.
Integrated-chip checks, organizer acceptance and pad-aware IR/EM remain separate.

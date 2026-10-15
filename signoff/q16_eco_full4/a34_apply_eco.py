#!/usr/bin/env python3
"""Apply the seven reviewed A34 cell-size ECOs, then reroute and check signoff.

Run in ~/openlane_project/a34-rtl-fix-pd inside the existing nix-shell.
Starts from FULL3's pre-detailed-routing checkpoint, not its routed/fill ODB.
Writes only new run/diagnostic directories. No edits to RTL/configuration,
published GDS/netlists, Git index, or existing runs. Does not commit or push.
Uses the original 45 ns constraints and PDK exclusions.
"""
from __future__ import annotations

import datetime as dt
import fnmatch
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import zipfile

PROBE = json.loads(r'''{
  "source_run": "/home/rumali/openlane_project/a34-rtl-fix-pd/librelane/runs/A34_Q16_FIX_FULL3",
  "initial_state": "/home/rumali/openlane_project/a34-rtl-fix-pd/librelane/runs/A34_Q16_FIX_FULL3/17-openroad-stapostpnr/state_in.json",
  "command": [
    "librelane",
    "--manual-pdk",
    "--pdk",
    "gf180mcuD",
    "--pdk-root",
    "/home/rumali/openlane_project/chipathon-2026-systolic-ip-core-main-git/gf180mcu",
    "--jobs",
    "2",
    "--run-tag",
    "A34_Q16_ECO_PROBE_20261015_154111_6qj3",
    "--from",
    "OpenROAD.STAPostPNR",
    "--to",
    "OpenROAD.STAPostPNR",
    "--with-initial-state",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/librelane/runs/A34_Q16_FIX_FULL3/17-openroad-stapostpnr/state_in.json",
    "--override-config",
    "STA_EXTRA_CORNER_TCL_FILE=/home/rumali/openlane_project/a34-rtl-fix-pd/verification_results/eco-timing-probe-fjjv6qj3/probe_hook.tcl",
    "--override-config",
    "SIGNOFF_SDC_FILE=/home/rumali/openlane_project/a34-rtl-fix-pd/librelane/chip_core.sdc",
    "--override-config",
    "STA_CORNERS=nom_tt_025C_5v00 nom_ss_125C_4v50 nom_ff_n40C_5v50 min_tt_025C_5v00 min_ss_125C_4v50 min_ff_n40C_5v50 max_tt_025C_5v00 max_ss_125C_4v50 max_ff_n40C_5v50",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/librelane/chip_core_macro.yaml"
  ],
  "candidate_changes": [
    [
      "_29775_",
      "gf180mcu_fd_sc_mcu7t5v0__oai32_1",
      "gf180mcu_fd_sc_mcu7t5v0__oai32_2"
    ],
    [
      "_34089_",
      "gf180mcu_fd_sc_mcu7t5v0__oai33_1",
      "gf180mcu_fd_sc_mcu7t5v0__oai33_4"
    ],
    [
      "_29733_",
      "gf180mcu_fd_sc_mcu7t5v0__nor3_1",
      "gf180mcu_fd_sc_mcu7t5v0__nor3_2"
    ],
    [
      "clkbuf_leaf_259_clk",
      "gf180mcu_fd_sc_mcu7t5v0__clkbuf_8",
      "gf180mcu_fd_sc_mcu7t5v0__clkbuf_4"
    ],
    [
      "clkbuf_leaf_257_clk",
      "gf180mcu_fd_sc_mcu7t5v0__clkbuf_8",
      "gf180mcu_fd_sc_mcu7t5v0__clkbuf_4"
    ],
    [
      "clkbuf_leaf_541_clk",
      "gf180mcu_fd_sc_mcu7t5v0__clkbuf_8",
      "gf180mcu_fd_sc_mcu7t5v0__clkbuf_4"
    ],
    [
      "clkbuf_leaf_519_clk",
      "gf180mcu_fd_sc_mcu7t5v0__clkbuf_8",
      "gf180mcu_fd_sc_mcu7t5v0__clkbuf_4"
    ]
  ],
  "unresolved_instances": [],
  "clock_leaf_selection": [
    [
      "clkbuf_6_48__f_clk",
      "clkbuf_leaf_259_clk",
      "5"
    ],
    [
      "clkbuf_6_48__f_clk",
      "clkbuf_leaf_257_clk",
      "7"
    ],
    [
      "clkbuf_6_36__f_clk",
      "clkbuf_leaf_541_clk",
      "4"
    ],
    [
      "clkbuf_6_36__f_clk",
      "clkbuf_leaf_519_clk",
      "6"
    ]
  ],
  "source_sha256": {
    "/home/rumali/openlane_project/a34-rtl-fix-pd/librelane/chip_core_macro.yaml": "cbc5d083081c63eaf15fa8e15c6e112cb2289267f22a9b2decc906f73895489e",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/librelane/chip_core.sdc": "4b75471dd00d5db7fe6a694220f719d6de5578534f8730508c37c4e0f76253b5",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/librelane/runs/A34_Q16_FIX_FULL3/final/odb/chip_core.odb": "2fdb8b7ed8af82e3fa493e3a0ce9e1e6837c90ce1248455cf128c6b7560b36e8",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/librelane/runs/A34_Q16_FIX_FULL3/14-openroad-fillinsertion/chip_core.nl.v": "76b1624204c7aebe60d01d2f3e3d71f4573dfd7dffc4cfa1484a1f63743aa6c8",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/rtl/controlled_counter.v": "b7b3bb8f1b1852c2f4d24b6d0e24ea2444cb461d2c7ff005cecec0cdd0feba29",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/rtl/counter.v": "71d0f475cfc1a45b6fb050de1ef85269351df491e320419c6f452945a987d7ab",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/rtl/data_feeder.v": "1fd14325815e9b798e454cb62c2191a5b61a77b81c3d4b43e8d725dd0dd7d362",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/rtl/fp16_approximate_multiplier.v": "d2677c740a7ff7534c2f7105d5b1060ef40c1b7de950cf96dad6c92b3df437b6",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/rtl/fp16_multiplier_exception.v": "a36a962fdb36e5e365534432512226ae149c496ac90e9f39ac55a878bd6c629c",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/rtl/fp16_multiplier_exponent.v": "433bab9f2e8c68b1effc7dc4709b5aec7c33831ecdda86c2dfce63d5589cd51c",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/rtl/fp16_to_fp32.v": "abeb531813f87ac390aec7d1b2c9914a6a5f06f2163cb77ff17941faea921bfb",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/rtl/fp16_to_q16_16.v": "3cdbd7eb955dc5deac2b7773359113ae3eb82abc94d713f3360b083c6c659357",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/rtl/fp16_to_q16_16_approximate_mac.v": "bc6acdaa7cc10ea4c7faf31916336111d0b3b8f1dc8392423c4789a65bd8ce06",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/rtl/fp16_to_q8_8.v": "f2d30149003a9c1522a94cdc5f319ede82719f77e7a67bbbcbc783971871060c",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/rtl/fp32_to_fp16.v": "9093a621f0b53f8f58a28c5ff845d6f46eac813db8646710f277e79fd3ffdcea",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/rtl/input_datapath.v": "740bab48d8887c72950bff3636f13d9fc55f604b1e018970e1b18ea474be3b2a",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/rtl/output_datapath.v": "b492c92284dab64ddf3e925b66af667768ec02c2b8eb376fad62c10a2a61dccc",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/rtl/pe.v": "bc11faca2d013fde4f3eca4cd92b8542897678e82fd2756d8c7e4c6f7bae7296",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/rtl/q16_16_to_fp16.v": "f87830cf35aaaa01d2a2044ad19e6f917226385b71f8b5608a97f4f4794caaaa",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/rtl/q16_16_to_fp32.v": "2bb1271562d026ea2dbf6e1847a803a9c5fdd44d33348b1fed795ed06212f8b6",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/rtl/reg_def.v": "b4a7953bdf6168d1a0561c8c71d1f1c6ee558c925a7479a69fbdda6d3d0f9fea",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/rtl/rv_protocol.v": "b56b55fb939fc6f72fa3e90f7160bcf8de6c6e3c6c3d1fefea239ecc42d4394e",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/rtl/systolic.v": "344246aadef5671a7b1676b6f761010bce44dcedb1bcc778d7515b15ae946c24",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/chipathon_wrapper/chip_core.sv": "0f0a56363ac9183676f937412dafb8ddee4fd07f53e265a09335916f96801c22",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/chipathon_wrapper/chip_top.sv": "90d97b00e1ca9e05f26e5f028aa588de3ec546e600da5c209a1eafa5ea62da3d",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/rtl/input_serializer.sv": "96fba49d65b689538807e67d63c474e536248a32d81a26691d1ef6dc4d8a918b",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/tb/chip_core_tb.sv": "88003aaba730e187d187727c27ab2fde604e6e11a3beb3ed7ac0808f2e708d22",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/tb/counter_tb.sv": "3242819b75833b25f95ba6bfac2ea6cbd556aa346dbe649af192124e07247f29",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/tb/data_feeder_tb.sv": "98233d431ea8ba054b1a3eb4e6f168cf9331eacec21b271b86487bb9dff1bb75",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/tb/fp16_to_q16_16_approximate_mac_tb.sv": "c81a948eaa7a84f04950bc0f4c18505eb30b9d45f30a0e8a2293ee51bb755e5a",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/tb/input_datapath_tb.sv": "890a9ed87af869025d333f66b943032f87668a77705b4a4c67e8bc62faecbcf0",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/tb/input_serializer_tb.sv": "012394fec666a986ba90c43e69d8121206113df2a42cd2fd308e0eea9190060e",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/tb/output_datapath_tb.sv": "8b1784be0b8b69856de2be55e219d04a37955a2490e391e3db9291ae71f49b5e",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/tb/pe_tb.sv": "d64be3da903caacf272490adee0b2ec3f115f6b41e5d51775251e211cb8db5e3",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/tb/rv_protocol_tb.sv": "386d2697690cc6a2eb9bfd336b0d8989e58d5aee5327b3aec2acc3f624dea5fb",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/src/tb/systolic_top_tb.sv": "16c9969be24711b1a8f43a6a968c2a544de396e35cc21f8dd8eaa8a6fcf6a799",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/librelane/runs/A34_Q16_FIX_FULL3/final/gds/chip_core.gds": "7e19865eec15ec570c5d7547bfa9009448c172896a5d6404ccab51454184cde0",
    "/home/rumali/openlane_project/a34-rtl-fix-pd/librelane/runs/A34_Q16_FIX_FULL3/final/pnl/chip_core.pnl.v": "beed138d771c6982a4001c040c527dec1b8faf389550b95524e609b149b2bf86"
  },
  "liberty_sha256": {
    "/home/rumali/openlane_project/chipathon-2026-systolic-ip-core-main-git/gf180mcu/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/lib/gf180mcu_fd_sc_mcu7t5v0__ss_125C_4v50.lib": "4c2657ae12581bc18ed408f3fda0accd10b855118b9993070dbb360dfa3aa874",
    "/home/rumali/openlane_project/chipathon-2026-systolic-ip-core-main-git/gf180mcu/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/lib/gf180mcu_fd_sc_mcu7t5v0__tt_025C_5v00.lib": "330aa9439255e3870ad7adfb987cd4d7bcfa7b6f9fb0cd0a712400e9bd80e38a",
    "/home/rumali/openlane_project/chipathon-2026-systolic-ip-core-main-git/gf180mcu/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/lib/gf180mcu_fd_sc_mcu7t5v0__ff_n40C_5v50.lib": "6e04fbedf4279c89a73d6caebe55de27bd760f1aa7c24a4c015489724e4c2439"
  },
  "scope": "In-memory cell substitutions on existing routed SPEFs; no placement/routing/signoff of modified design."
}
''')
PREFIX = "gf180mcu_fd_sc_mcu7t5v0__"
CHANGES = PROBE["candidate_changes"]
CORNERS = [f"{rc}_{pvt}" for rc in ("nom", "min", "max")
           for pvt in ("tt_025C_5v00", "ss_125C_4v50", "ff_n40C_5v50")]


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def sha(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def one(paths, label):
    found = list(paths)
    require(len(found) == 1, f"Expected one {label}; found {len(found)}.")
    return found[0]


def tq(value):
    return '"' + str(value).replace('\\', '\\\\').replace('"', '\\"').replace('$', '\\$').replace('[', '\\[').replace(']', '\\]') + '"'


def run_logged(argv, log):
    """Show tool progress and retain it; Ctrl-C also terminates child tools."""
    print("\nRunning:", " ".join(argv), flush=True)
    with log.open("w") as f:
        p = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             text=True, errors="replace", start_new_session=True)
        try:
            for line in p.stdout:
                f.write(line)
                f.flush()
                print(line, end="", flush=True)
            return p.wait()
        except BaseException:
            if p.poll() is None:
                os.killpg(p.pid, signal.SIGTERM)
                try:
                    p.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    os.killpg(p.pid, signal.SIGKILL)
                    p.wait()
            raise


COMMON_TCL = r'''
proc a34_boundary {block} {
    set rows {}
    foreach term [$block getBTerms] {
        set net [$term getNet]
        set net_name "<disconnected>"
        if {$net ne "NULL"} {set net_name [$net getName]}
        set header [list [$term getName] $net_name [$term getSigType] [$term getIoType]]
        lappend rows $header
        foreach pin [$term getBPins] {
            foreach box [$pin getBoxes] {
                set layer [$box getTechLayer]
                if {$layer eq "NULL"} {error "Boundary shape has no layer"}
                lappend rows [concat $header [list [$layer getName] [$box xMin] [$box yMin] [$box xMax] [$box yMax]]]
            }
        }
    }
    return [lsort -dictionary $rows]
}
proc a34_connections {inst} {
    set rows {}
    foreach term [$inst getITerms] {
        set net [$term getNet]
        set net_name "<disconnected>"
        if {$net ne "NULL"} {set net_name [$net getName]}
        lappend rows [list [[$term getMTerm] getName] $net_name [$term getIoType]]
    }
    return [lsort -dictionary $rows]
}
proc a34_master_pins {master} {
    set rows {}
    foreach term [$master getMTerms] {
        lappend rows [list [$term getName] [$term getIoType] [$term getSigType]]
    }
    return [lsort -dictionary $rows]
}
'''


def change_rows():
    return "\n".join("  " + " ".join(tq(v) for v in row) for row in CHANGES)


def apply_tcl(odb, new_odb, liberty):
    # OpenROAD attaches STA callbacks to dbInst::swapMaster. They require
    # non-null Liberty models for both masters, even for this database-only
    # edit. Match LibreLane's initialization order: Liberty, then ODB.
    # This single TT library is only for the swap callback; the subsequent
    # physical flow still loads its configured PnR and nine signoff corners.
    return COMMON_TCL + f"\nread_liberty {tq(liberty)}\nread_db {tq(odb)}\n" + r'''
set block [ord::get_db_block]
set db [ord::get_db]
set before_boundary [a34_boundary $block]
set before_count [llength [$block getInsts]]
set regular_wires 0
foreach net [$block getNets] {
    if {[$net getWire] ne "NULL"} {incr regular_wires}
}
if {$regular_wires != 0} {error "Checkpoint already has $regular_wires regular routed wires; inspect before editing"}
set changes {
''' + change_rows() + r'''
}
# Check all instances and replacement masters before making any substitutions.
foreach {name old new} $changes {
    set inst [$block findInst $name]
    if {$inst eq "NULL"} {error "Missing checkpoint instance $name"}
    set master [$inst getMaster]
    if {[$master getName] ne $old} {error "Unexpected original cell at $name"}
    if {[$inst isDoNotTouch]} {error "Instance is dont_touch: $name"}
    if {[$inst getPlacementStatus] ne "PLACED"} {error "Unexpected placement status at $name"}
    set target [$db findMaster $new]
    if {$target eq "NULL"} {error "Missing replacement LEF $new"}
    if {[a34_master_pins $master] ne [a34_master_pins $target]} {error "LEF pin interface differs at $name"}
    if {[$master getHeight] != [$target getHeight]} {error "Cell height differs at $name"}
    set sta_inst [sta::get_instance_error "instance" $name]
    set old_lib [$sta_inst liberty_cell]
    set new_lib [sta::get_lib_cell_warn "lib_cell" $new]
    if {$old_lib eq "NULL" || $old_lib eq "" || $new_lib eq "NULL" || $new_lib eq ""} {
        error "Missing linked Liberty model for $name: $old -> $new; no cells changed"
    }
    if {![sta::equiv_cell_ports $old_lib $new_lib]} {
        error "Liberty pin interface differs at $name; no cells changed"
    }
}
puts "A34_LIBERTY_PRECHECK_PASS 7"
foreach {name old new} $changes {
    set inst [$block findInst $name]
    set before [a34_connections $inst]
    if {![$inst swapMaster [$db findMaster $new]]} {error "swapMaster rejected $name"}
    if {[a34_connections $inst] ne $before} {error "Connectivity changed at $name"}
    puts "A34_APPLIED $name $old $new"
}
if {[llength [$block getInsts]] != $before_count} {error "Instance count changed unexpectedly"}
if {[a34_boundary $block] ne $before_boundary} {error "Boundary pins changed unexpectedly"}
puts "A34_BOUNDARY $before_boundary"
''' + f"write_db {tq(new_odb)}\n" + 'puts "A34_ECO_COPY_WRITTEN"\n'


def check_tcl(odb):
    return COMMON_TCL + f"\nread_db {tq(odb)}\n" + r'''
set block [ord::get_db_block]
set die [$block getDieArea]
set core [$block getCoreArea]
set dbu [$block getDbUnitsPerMicron]
puts "A34_BOUNDARY [a34_boundary $block]"
set changes {
''' + change_rows() + r'''
}
foreach {name old new} $changes {
    set inst [$block findInst $name]
    if {$inst eq "NULL" || [[$inst getMaster] getName] ne $new} {error "ECO cell missing or changed: $name"}
    puts "A34_FINAL_CELL $name $new"
}
foreach name {VDD VSS} {
    set net [$block findNet $name]
    if {$net eq "NULL"} {error "Power net missing: $name"}
    set m2 0
    foreach term [$net getBTerms] {
        foreach pin [$term getBPins] {
            foreach box [$pin getBoxes] {
                set layer [$box getTechLayer]
                if {$layer ne "NULL" && [$layer getName] eq "Metal2"} {incr m2}
            }
        }
    }
    set vertical 0
    set horizontal 0
    set outside 0
    foreach wire [$net getSWires] {
        foreach box [$wire getWires] {
            if {[$box xMin] < [$die xMin] || [$box yMin] < [$die yMin] ||
                [$box xMax] > [$die xMax] || [$box yMax] > [$die yMax]} {incr outside}
            if {[$box isVia]} {continue}
            set layer [$box getTechLayer]
            if {$layer eq "NULL"} {continue}
            set lname [$layer getName]
            if {$lname eq "Metal4" && ([$box xMax] <= [$core xMin] || [$box xMin] >= [$core xMax])} {incr vertical}
            if {$lname eq "Metal5" && ([$box yMax] <= [$core yMin] || [$box yMin] >= [$core yMax])} {incr horizontal}
        }
    }
    puts "A34_POWER $name M2=$m2 vertical_ring=$vertical horizontal_ring=$horizontal outside=$outside"
    if {$m2 != 6 || $vertical != 2 || $horizontal != 2 || $outside != 0} {error "Power geometry needs review on $name"}
    check_power_grid -net $name
}
puts "A34_FINAL_ODB_CHECK_COMPLETE"
'''


def clean_state(state, odb):
    # Preserve upstream logical/header views if present, but discard obsolete
    # physical/extracted views. DetailedPlacement writes new ODB/DEF/NL/PNL/SDC.
    state = dict(state)
    for key in ("def", "sdc", "nl", "pnl", "spef", "sdf", "gds", "mag_gds",
                "klayout_gds", "lef", "openroad_lef", "spice", "sdf_pnl"):
        if key in state:
            state[key] = None
    state["odb"] = str(odb)
    state["metrics"] = {}
    return state


def inspect_metrics(run):
    metrics_path = run / "final/metrics.json"
    require(metrics_path.is_file(), "Final metrics.json is missing; flow completion needs review.")
    m = json.loads(metrics_path.read_text())
    errors, lines = [], []
    zero_keys = [
        "design__max_slew_violation__count", "design__max_cap_violation__count",
        "design__max_fanout_violation__count", "timing__setup_vio__count",
        "timing__hold_vio__count", "timing__setup__wns", "timing__hold__wns",
        "timing__setup__tns", "timing__hold__tns", "route__drc_errors",
        "magic__drc_error__count", "klayout__drc_error__count",
        "antenna__violating__nets", "antenna__violating__pins",
        "route__antenna_violation__count", "design__lvs_error__count",
        "design__lvs_device_difference__count", "design__lvs_net_difference__count",
        "design__lvs_property_fail__count", "design__lvs_unmatched_device__count",
        "design__lvs_unmatched_net__count", "design__lvs_unmatched_pin__count",
    ]
    for key in zero_keys:
        value = m.get(key)
        lines.append(f"{key}: {value}")
        if value is None or float(value) != 0:
            errors.append(f"{key}: {value}")
    for corner in CORNERS:
        for kind in ("setup", "hold"):
            key = f"timing__{kind}_vio__count__corner:{corner}"
            if m.get(key) is None or float(m[key]) != 0:
                errors.append(f"{key}: {m.get(key)}")
        for kind in ("slew", "cap", "fanout"):
            key = f"design__max_{kind}_violation__count__corner:{corner}"
            if m.get(key) is None or float(m[key]) != 0:
                errors.append(f"{key}: {m.get(key)}")
        ws = []
        for kind in ("setup", "hold"):
            key = f"timing__{kind}__ws__corner:{corner}"
            value = m.get(key)
            if value is None or not math.isfinite(float(value)) or float(value) < 0:
                errors.append(f"{key}: {value}")
            ws.append(value)
        lines.append(f"{corner}: setup_ws={ws[0]} ns; hold_ws={ws[1]} ns")
    return errors, lines


def check_gds(gds):
    import klayout.db as kdb
    layout = kdb.Layout()
    layout.read(str(gds))
    tops = list(layout.top_cells())
    require(len(tops) == 1 and tops[0].name == "chip_core", "Unexpected GDS top cells.")
    box, dbu = tops[0].bbox(), layout.dbu
    coords = [box.left*dbu, box.bottom*dbu, box.right*dbu, box.top*dbu]
    require(abs(dbu - 0.001) < 1e-12, f"Unexpected GDS DBU: {dbu}")
    require(all(abs(a-b) < 1e-6 for a, b in zip(coords, [0, 0, 1675, 1675])),
            f"Unexpected GDS boundary: {coords}")
    return f"GDS: top=chip_core, DBU={dbu} um, boundary={coords} um"


def package(out, run, tag):
    if run.exists():
        patterns = ["final/metrics.json", "final/metrics.csv", "*-openroad-stapostpnr/summary.rpt",
                    "*-openroad-stapostpnr/*/checks.rpt", "*-netgen-lvs/netgen-lvs.log",
                    "*-netgen-lvs/reports/lvs.netgen.rpt", "*-openroad-detailedplacement/config.json",
                    "*-openroad-stapostpnr/config.json"]
        for pattern in patterns:
            for p in run.glob(pattern):
                target = out / "run_reports" / p.relative_to(run)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(p, target)
    archive = out / (tag + "_reports.zip")
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
        for p in sorted(out.rglob("*")):
            if p.is_file() and p != archive and p.suffix != ".odb":
                z.write(p, str(p.relative_to(out)))
    downloads = Path("/mnt/c/Users/User20/Downloads")
    if downloads.is_dir():
        target = downloads / archive.name
        require(not target.exists(), f"Archive already exists: {target}")
        shutil.copy2(archive, target)
        print("\nUPLOAD REPORT ZIP:", target)
    else:
        print("\nUPLOAD REPORT ZIP:", archive)


def main():
    print("A34 PHYSICAL ECO revision 2 (Liberty initialization fix)", flush=True)
    root = Path.cwd().resolve()
    source_run = Path(PROBE["source_run"])
    require(root == source_run.parents[2], "Run from ~/openlane_project/a34-rtl-fix-pd.")
    require(len(CHANGES) == 7 and not PROBE["unresolved_instances"], "Invalid embedded ECO selection.")
    for tool in ("librelane", "openroad"):
        require(shutil.which(tool), f"{tool} missing; enter this project's nix-shell.")
    from importlib.metadata import version
    require(version("librelane") == "3.0.0", "This procedure is for LibreLane 3.0.0.")
    import klayout.db  # Check the final geometry-check dependency before starting.
    protected = dict(PROBE["source_sha256"])
    protected.update(PROBE["liberty_sha256"])
    for path, digest in protected.items():
        require(Path(path).is_file() and sha(path) == digest,
                f"File differs from the reviewed timing probe: {path}")
    swap_liberty = one(
        [Path(p) for p in PROBE["liberty_sha256"]
         if Path(p).name == PREFIX + "tt_025C_5v00.lib"],
        "verified TT standard-cell Liberty file",
    )
    yaml = root / "librelane/chip_core_macro.yaml"
    drt_step = one(source_run.glob("*-openroad-detailedrouting"), "FULL3 detailed-routing step")
    cfg = json.loads((drt_step / "config.json").read_text())
    pre_state_file = drt_step / "state_in.json"
    state = json.loads(pre_state_file.read_text())
    pre_odb = Path(state["odb"])
    require(pre_odb.is_file(), "Pre-routing checkpoint database is missing.")
    require(cfg["PDK"] == "gf180mcuD" and float(cfg["CLOCK_PERIOD"]) == 45,
            "Unexpected PDK or clock period.")
    require(not cfg.get("STA_EXTRA_CORNER_TCL_FILE"), "A custom STA hook needs review.")
    exclusions = list(cfg.get("EXTRA_EXCLUDED_CELLS") or [])
    if cfg.get("PNR_EXCLUDED_CELL_FILE"):
        exclusion_file = Path(cfg["PNR_EXCLUDED_CELL_FILE"])
        for line in exclusion_file.read_text().splitlines():
            exclusions.extend(line.split("#", 1)[0].split())
        protected[str(exclusion_file)] = sha(exclusion_file)
    for _, _, new in CHANGES:
        require(not any(fnmatch.fnmatchcase(new, pattern) for pattern in exclusions),
                f"Replacement cell is excluded: {new}")
    for key in ("PDN_CFG", "FP_DEF_TEMPLATE", "PNR_SDC_FILE", "SIGNOFF_SDC_FILE"):
        if cfg.get(key):
            p = Path(cfg[key])
            require(p.is_file(), f"Missing {key}: {p}")
            protected[str(p)] = sha(p)
    protected[str(pre_odb)] = sha(pre_odb)
    protected[str(pre_state_file)] = sha(pre_state_file)
    outparent = root / "verification_results"
    outparent.mkdir(exist_ok=True)
    out = Path(tempfile.mkdtemp(prefix="physical-eco-", dir=outparent))
    tag = "A34_Q16_ECO_FULL4_" + dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    run = root / "librelane/runs" / tag
    require(not run.exists(), f"Run already exists: {run}")
    shutil.copy2(Path(__file__), out / "a34_apply_eco.py")
    (out / "probe_provenance.json").write_text(json.dumps(PROBE, indent=2) + "\n")
    print("PREFLIGHT PASS: files match the successful seven-cell timing probe.")
    print("New run:", run)
    print("Diagnostics:", out)
    print("No RTL/config edits, no commits/pushes, and no replacement of submitted outputs.")
    errors, lines = [], []
    try:
        edited = out / "chip_core.eco_unlegalized.odb"
        apply_script = out / "apply_seven_cells.tcl"
        apply_script.write_text(apply_tcl(pre_odb, edited, swap_liberty))
        require(run_logged(["openroad", "-exit", str(apply_script)], out / "apply.log") == 0,
                "Cell-change preparation failed; inspect apply.log.")
        apply_log = (out / "apply.log").read_text()
        require("A34_LIBERTY_PRECHECK_PASS 7" in apply_log,
                "Seven-cell Liberty precheck did not complete.")
        require("A34_ECO_COPY_WRITTEN" in apply_log and edited.is_file(), "Edited database was not written.")
        require(len(re.findall(r'^A34_APPLIED ', apply_log, re.M)) == 7, "Expected exactly seven cell changes.")
        boundary = one(re.findall(r'^A34_BOUNDARY (.*)$', apply_log, re.M), "boundary snapshot")
        initial = out / "eco_state_in.json"
        initial.write_text(json.dumps(clean_state(state, edited), indent=2) + "\n")
        # The checkpoint already contains CTS, timing repair, and port diodes.
        # Rerun legalization and routing. Do not rebuild CTS or let general
        # sizing passes undo the seven specifically evaluated substitutions.
        skips = ["OpenROAD.CTS", "OpenROAD.ResizerTimingPostCTS",
                 "OpenROAD.RepairDesignPostGRT", "OpenROAD.ResizerTimingPostGRT",
                 "Odb.DiodesOnPorts", "Odb.HeuristicDiodeInsertion"]
        argv = ["librelane", "--manual-pdk", "--pdk", "gf180mcuD", "--pdk-root", cfg["PDK_ROOT"],
                "--run-tag", tag, "--from", "OpenROAD.DetailedPlacement",
                "--with-initial-state", str(initial)]
        for step in skips:
            argv += ["--skip", step]
        # Explicitly run routing, extraction, STA and physical verification.
        # These flags enable checks; no timing/electrical limits are relaxed.
        for key in ("RUN_DRT", "RUN_FILL_INSERTION", "RUN_ANTENNA_REPAIR", "RUN_SPEF_EXTRACTION",
                    "RUN_MCSTA", "RUN_LVS", "RUN_MAGIC_STREAMOUT", "RUN_KLAYOUT_STREAMOUT",
                    "RUN_MAGIC_DRC", "RUN_KLAYOUT_DRC"):
            argv += ["--override-config", key + "=true"]
        argv += ["--override-config", "STA_CORNERS=" + " ".join(CORNERS), str(yaml)]
        (out / "eco_run_manifest.json").write_text(json.dumps({
            "run": str(run), "initial_checkpoint": str(pre_state_file), "command": argv,
            "cell_changes": CHANGES, "skipped_already_completed_optimization": skips,
            "protected_sha256": protected,
            "scope": "Local seven-cell ECO, legalization, rerouting, extraction and block signoff; not integrated-chip approval."
        }, indent=2) + "\n")
        print("\nStarting physical implementation and signoff. Keep this terminal open.", flush=True)
        code = run_logged(argv, out / "physical_flow.log")
        if code != 0:
            errors.append(f"LibreLane exited with code {code}; see physical_flow.log.")
        if (run / "final/metrics.json").is_file():
            metric_errors, metric_lines = inspect_metrics(run)
            errors += metric_errors
            lines += metric_lines
            lvs_log = one(run.glob("*-netgen-lvs/netgen-lvs.log"), "LVS log")
            require("Circuits match uniquely." in lvs_log.read_text(), "LVS unique-match message missing.")
            final_odb = run / "final/odb/chip_core.odb"
            final_check = out / "check_final_eco.tcl"
            final_check.write_text(check_tcl(final_odb))
            require(run_logged(["openroad", "-exit", str(final_check)], out / "final_odb_check.log") == 0,
                    "Final cell/power geometry check needs review.")
            checked = (out / "final_odb_check.log").read_text()
            require("A34_FINAL_ODB_CHECK_COMPLETE" in checked, "Final ODB check incomplete.")
            require(one(re.findall(r'^A34_BOUNDARY (.*)$', checked, re.M), "final boundary") == boundary,
                    "Boundary terminals differ from the input checkpoint.")
            for name in ("VDD", "VSS"):
                require(f"All shapes on net {name} are connected." in checked,
                        f"Power connectivity pass missing for {name}.")
            lines += ["All boundary terminals preserved; all seven ECO cells present.",
                      "VDD/VSS connectivity passed; six Metal2 terminals and four ring sides per net; no power shapes outside die."]
            lines.append(check_gds(run / "final/gds/chip_core.gds"))
            final_hashes = {}
            for rel in ("gds/chip_core.gds", "odb/chip_core.odb", "def/chip_core.def", "pnl/chip_core.pnl.v"):
                path = run / "final" / rel
                require(path.is_file(), f"Final deliverable missing: {path}")
                final_hashes[rel] = sha(path)
            (out / "final_sha256.json").write_text(json.dumps(final_hashes, indent=2) + "\n")
        else:
            errors.append("No complete final metrics available.")
    except KeyboardInterrupt:
        errors.append("Run interrupted. Existing submitted design and FULL3 remain protected.")
    except Exception as exc:
        errors.append(str(exc))
    finally:
        changed = [p for p, digest in protected.items() if not Path(p).is_file() or sha(p) != digest]
        if changed:
            errors += ["Protected file changed: " + p for p in changed]
        else:
            lines.append("Protected source files, PDK libraries and original run files unchanged.")
        status = "REVIEW REQUIRED" if errors else "LOCAL ECO CHECKS PASS"
        lines += [status] + errors
        lines += ["Integrated-chip DRC/LVS and pad-aware IR/EM assessment are outside this check.",
                  "No files copied to submission paths; no Git staging, commits or pushes performed.", f"Run: {run}"]
        (out / "eco_summary.txt").write_text("\n".join(lines) + "\n")
        print("\n" + "\n".join(lines), flush=True)
        package(out, run, tag)
    return 1 if errors else 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"STOP: {exc}", file=sys.stderr)
        raise SystemExit(1)

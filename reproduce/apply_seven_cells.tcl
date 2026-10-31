# Portable copy of signoff/q16_eco_full4/apply_seven_cells.tcl: identical
# logic, with the three file paths taken from environment variables
# (A34_LIBERTY, A34_ECO_IN_ODB, A34_ECO_OUT_ODB) set by replay_eco.sh.

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

read_liberty $::env(A34_LIBERTY)
read_db $::env(A34_ECO_IN_ODB)

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
  "_29775_" "gf180mcu_fd_sc_mcu7t5v0__oai32_1" "gf180mcu_fd_sc_mcu7t5v0__oai32_2"
  "_34089_" "gf180mcu_fd_sc_mcu7t5v0__oai33_1" "gf180mcu_fd_sc_mcu7t5v0__oai33_4"
  "_29733_" "gf180mcu_fd_sc_mcu7t5v0__nor3_1" "gf180mcu_fd_sc_mcu7t5v0__nor3_2"
  "clkbuf_leaf_259_clk" "gf180mcu_fd_sc_mcu7t5v0__clkbuf_8" "gf180mcu_fd_sc_mcu7t5v0__clkbuf_4"
  "clkbuf_leaf_257_clk" "gf180mcu_fd_sc_mcu7t5v0__clkbuf_8" "gf180mcu_fd_sc_mcu7t5v0__clkbuf_4"
  "clkbuf_leaf_541_clk" "gf180mcu_fd_sc_mcu7t5v0__clkbuf_8" "gf180mcu_fd_sc_mcu7t5v0__clkbuf_4"
  "clkbuf_leaf_519_clk" "gf180mcu_fd_sc_mcu7t5v0__clkbuf_8" "gf180mcu_fd_sc_mcu7t5v0__clkbuf_4"
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
write_db $::env(A34_ECO_OUT_ODB)
puts "A34_ECO_COPY_WRITTEN"

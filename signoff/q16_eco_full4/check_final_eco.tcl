
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

read_db "/home/rumali/openlane_project/a34-rtl-fix-pd/librelane/runs/A34_Q16_ECO_FULL4_20261015_160735/final/odb/chip_core.odb"

set block [ord::get_db_block]
set die [$block getDieArea]
set core [$block getCoreArea]
set dbu [$block getDbUnitsPerMicron]
puts "A34_BOUNDARY [a34_boundary $block]"
set changes {
  "_29775_" "gf180mcu_fd_sc_mcu7t5v0__oai32_1" "gf180mcu_fd_sc_mcu7t5v0__oai32_2"
  "_34089_" "gf180mcu_fd_sc_mcu7t5v0__oai33_1" "gf180mcu_fd_sc_mcu7t5v0__oai33_4"
  "_29733_" "gf180mcu_fd_sc_mcu7t5v0__nor3_1" "gf180mcu_fd_sc_mcu7t5v0__nor3_2"
  "clkbuf_leaf_259_clk" "gf180mcu_fd_sc_mcu7t5v0__clkbuf_8" "gf180mcu_fd_sc_mcu7t5v0__clkbuf_4"
  "clkbuf_leaf_257_clk" "gf180mcu_fd_sc_mcu7t5v0__clkbuf_8" "gf180mcu_fd_sc_mcu7t5v0__clkbuf_4"
  "clkbuf_leaf_541_clk" "gf180mcu_fd_sc_mcu7t5v0__clkbuf_8" "gf180mcu_fd_sc_mcu7t5v0__clkbuf_4"
  "clkbuf_leaf_519_clk" "gf180mcu_fd_sc_mcu7t5v0__clkbuf_8" "gf180mcu_fd_sc_mcu7t5v0__clkbuf_4"
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

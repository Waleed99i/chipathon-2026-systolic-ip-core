# Copyright 2025 LibreLane Contributors
#
# Adapted from OpenLane
#
# Copyright 2020-2022 Efabless Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

source $::env(SCRIPTS_DIR)/openroad/common/io.tcl
source $::env(SCRIPTS_DIR)/openroad/common/set_global_connections.tcl
set_global_connections

set secondary []
foreach vdd $::env(VDD_NETS) gnd $::env(GND_NETS) {
    if { $vdd != $::env(VDD_NET)} {
        lappend secondary $vdd

        set db_net [[ord::get_db_block] findNet $vdd]
        if {$db_net == "NULL"} {
            set net [odb::dbNet_create [ord::get_db_block] $vdd]
            $net setSpecial
            $net setSigType "POWER"
        }
    }

    if { $gnd != $::env(GND_NET)} {
        lappend secondary $gnd

        set db_net [[ord::get_db_block] findNet $gnd]
        if {$db_net == "NULL"} {
            set net [odb::dbNet_create [ord::get_db_block] $gnd]
            $net setSpecial
            $net setSigType "GROUND"
        }
    }
}

set_voltage_domain -name CORE -power $::env(VDD_NET) -ground $::env(GND_NET) \
    -secondary_power $secondary



if { $::env(PDN_MULTILAYER) == 1 } {

    set arg_list [list]
    if { $::env(PDN_ENABLE_PINS) } {
        lappend arg_list -pins "$::env(PDN_VERTICAL_LAYER) $::env(PDN_HORIZONTAL_LAYER)"
    }

    define_pdn_grid \
        -name stdcell_grid \
        -starts_with POWER \
        -voltage_domain CORE \
        {*}$arg_list

    set arg_list [list]
    append_if_equals arg_list PDN_EXTEND_TO "core_ring" -extend_to_core_ring
    append_if_equals arg_list PDN_EXTEND_TO "boundary" -extend_to_boundary

    add_pdn_stripe \
        -grid stdcell_grid \
        -layer $::env(PDN_VERTICAL_LAYER) \
        -width $::env(PDN_VWIDTH) \
        -pitch $::env(PDN_VPITCH) \
        -offset $::env(PDN_VOFFSET) \
        -spacing $::env(PDN_VSPACING) \
        -starts_with POWER \
        {*}$arg_list

    add_pdn_stripe \
        -grid stdcell_grid \
        -layer $::env(PDN_HORIZONTAL_LAYER) \
        -width $::env(PDN_HWIDTH) \
        -pitch $::env(PDN_HPITCH) \
        -offset $::env(PDN_HOFFSET) \
        -spacing $::env(PDN_HSPACING) \
        -starts_with POWER \
        {*}$arg_list

    add_pdn_connect \
        -grid stdcell_grid \
        -layers "$::env(PDN_VERTICAL_LAYER) $::env(PDN_HORIZONTAL_LAYER)"
} else {

    set arg_list [list]
    if { $::env(PDN_ENABLE_PINS) } {
        lappend arg_list -pins "$::env(PDN_VERTICAL_LAYER)"
    }

    define_pdn_grid \
        -name stdcell_grid \
        -starts_with POWER \
        -voltage_domain CORE \
        {*}$arg_list

    set arg_list [list]
    append_if_equals arg_list PDN_EXTEND_TO "core_ring" -extend_to_core_ring
    append_if_equals arg_list PDN_EXTEND_TO "boundary" -extend_to_boundary

    add_pdn_stripe \
        -grid stdcell_grid \
        -layer $::env(PDN_VERTICAL_LAYER) \
        -width $::env(PDN_VWIDTH) \
        -pitch $::env(PDN_VPITCH) \
        -offset $::env(PDN_VOFFSET) \
        -spacing $::env(PDN_VSPACING) \
        -starts_with POWER \
        {*}$arg_list
}

# Adds the standard cell rails if enabled.
if { $::env(PDN_ENABLE_RAILS) == 1 } {
    add_pdn_stripe \
        -grid stdcell_grid \
        -layer $::env(PDN_RAIL_LAYER) \
        -width $::env(PDN_RAIL_WIDTH) \
        -followpins

    add_pdn_connect \
        -grid stdcell_grid \
        -layers "$::env(PDN_RAIL_LAYER) $::env(PDN_VERTICAL_LAYER)"
}


# Adds the core ring if enabled.
if { $::env(PDN_CORE_RING) == 1 } {
    if { $::env(PDN_MULTILAYER) == 1 } {
        set arg_list [list]
        append_if_flag arg_list PDN_CORE_RING_ALLOW_OUT_OF_DIE -allow_out_of_die
        append_if_flag arg_list PDN_CORE_RING_CONNECT_TO_PADS -connect_to_pads
        append_if_equals arg_list PDN_EXTEND_TO "boundary" -extend_to_boundary

        set pdn_core_vertical_layer $::env(PDN_VERTICAL_LAYER)
        set pdn_core_horizontal_layer $::env(PDN_HORIZONTAL_LAYER)

        if { [info exists ::env(PDN_CORE_VERTICAL_LAYER)] } {
            set pdn_core_vertical_layer $::env(PDN_CORE_VERTICAL_LAYER)
        }

        if { [info exists ::env(PDN_CORE_HORIZONTAL_LAYER)] } {
            set pdn_core_horizontal_layer $::env(PDN_CORE_HORIZONTAL_LAYER)
        }

        add_pdn_ring \
            -grid stdcell_grid \
            -layers "$pdn_core_vertical_layer $pdn_core_horizontal_layer" \
            -widths "$::env(PDN_CORE_RING_VWIDTH) $::env(PDN_CORE_RING_HWIDTH)" \
            -spacings "$::env(PDN_CORE_RING_VSPACING) $::env(PDN_CORE_RING_HSPACING)" \
            -core_offset "$::env(PDN_CORE_RING_VOFFSET) $::env(PDN_CORE_RING_HOFFSET)" \
            {*}$arg_list

        if { [info exists ::env(PDN_CORE_VERTICAL_LAYER)] } {
            add_pdn_connect \
                -grid stdcell_grid \
                -layers "$::env(PDN_CORE_VERTICAL_LAYER) $::env(PDN_HORIZONTAL_LAYER)"
        }

        if { [info exists ::env(PDN_CORE_HORIZONTAL_LAYER)] } {
            add_pdn_connect \
                -grid stdcell_grid \
                -layers "$::env(PDN_CORE_HORIZONTAL_LAYER) $::env(PDN_VERTICAL_LAYER)"
        }

        if { [info exists ::env(PDN_CORE_VERTICAL_LAYER)] && [info exists ::env(PDN_CORE_HORIZONTAL_LAYER)] } {
            add_pdn_connect \
                -grid stdcell_grid \
                -layers "$::env(PDN_CORE_VERTICAL_LAYER) $::env(PDN_CORE_HORIZONTAL_LAYER)"
        }

    } else {
        throw APPLICATION "PDN_CORE_RING cannot be used when PDN_MULTILAYER is set to false."
    }
}

define_pdn_grid \
    -macro \
    -default \
    -name macro \
    -starts_with POWER \
    -halo "$::env(PDN_HORIZONTAL_HALO) $::env(PDN_VERTICAL_HALO)"

add_pdn_connect \
    -grid macro \
    -layers "$::env(PDN_VERTICAL_LAYER) $::env(PDN_HORIZONTAL_LAYER)"

# No custom per-macro PDN grids for the workshop slot: the core
# holds only a 20-bit counter, no SRAMs, so the generic `macro` grid
# above covers the chip_id / logo placeholders.

# A34_BOUNDARY_POWER_BRIDGES
#
# Each fixed Metal2 VDD/VSS boundary rectangle receives a localized
# horizontal Metal3 bridge. PDNGen then connects Metal2-to-Metal3 at
# the terminal and Metal3-to-Metal4 where the bridge crosses the
# existing vertical Metal4 grid.
set a34_block [ord::get_db_block]
set a34_core [$a34_block getCoreArea]
set a34_core_ymin [$a34_core yMin]
set a34_dbu_per_micron [$a34_block getDbUnitsPerMicron]


# A34_POWER_PIN_GEOMETRY
#
# LibreLane applies FP_DEF_TEMPLATE after GeneratePDN in the Classic flow.
# Recreate the fixed A34 Metal2 power-terminal geometry here so PDNGen
# can connect it. Coordinates are copied exactly from A34_ACE_scaled.def.
set a34_metal2 [[ord::get_db_tech] findLayer Metal2]

set a34_power_pin_rectangles(VSS) {
    {0 268280 2000 287280}
    {0 241980 2000 262480}
    {0 218280 2000 238780}
    {0 191220 2000 211720}
    {0 167520 2000 188020}
    {0 142720 2000 161720}
}

set a34_power_pin_rectangles(VDD) {
    {0 468280 2000 487280}
    {0 441980 2000 462480}
    {0 418280 2000 438780}
    {0 391220 2000 411720}
    {0 367520 2000 388020}
    {0 342720 2000 361720}
}

foreach a34_power_net_name {VSS VDD} {
    set a34_power_net [$a34_block findNet $a34_power_net_name]

    if {$a34_power_net == "NULL"} {
        error "A34 pin creation: unable to find net $a34_power_net_name"
    }

    if {$a34_power_net_name == "VSS"} {
        set a34_sig_type GROUND
    } else {
        set a34_sig_type POWER
    }

    $a34_power_net setSpecial
    $a34_power_net setSigType $a34_sig_type

    set a34_power_bterm [$a34_block findBTerm $a34_power_net_name]

    if {$a34_power_bterm == "NULL"} {
        set a34_power_bterm \
            [odb::dbBTerm_create $a34_power_net $a34_power_net_name]
        $a34_power_bterm setIoType INOUT
    }

    $a34_power_bterm setSigType $a34_sig_type

    set a34_has_metal2_geometry 0
    foreach a34_existing_bpin [$a34_power_bterm getBPins] {
        foreach a34_existing_box [$a34_existing_bpin getBoxes] {
            set a34_existing_layer [$a34_existing_box getTechLayer]
            if {$a34_existing_layer != "NULL"
                && [$a34_existing_layer getName] == "Metal2"} {
                set a34_has_metal2_geometry 1
            }
        }
    }

    if {!$a34_has_metal2_geometry} {
        set a34_power_bpin [odb::dbBPin_create $a34_power_bterm]

        foreach a34_rect \
            $a34_power_pin_rectangles($a34_power_net_name) {
            lassign $a34_rect x1 y1 x2 y2
            odb::dbBox_create \
                $a34_power_bpin $a34_metal2 \
                $x1 $y1 $x2 $y2
        }

        $a34_power_bpin setPlacementStatus FIRM
    }
}

# A34_LOCAL_METAL3_BRIDGES
#
# Use short existing-routing shapes rather than full-width PDN stripes.
# They extend only 30 um from the left boundary, reaching the first
# Metal4 VDD/VSS strap pair without crossing the complete core.
set a34_metal3 [[ord::get_db_tech] findLayer Metal3]
set a34_bridge_xmax 60000
set a34_bridge_half_width 1600

foreach a34_net_name {VSS VDD} {
    set a34_net [$a34_block findNet $a34_net_name]

    if {$a34_net == "NULL"} {
        error "A34 bridge: unable to find net $a34_net_name"
    }

    set a34_swire [odb::dbSWire_create $a34_net "ROUTED"]

    foreach a34_bterm [$a34_net getBTerms] {
        foreach a34_bpin [$a34_bterm getBPins] {
            foreach a34_box [$a34_bpin getBoxes] {
                set a34_layer [$a34_box getTechLayer]

                if {$a34_layer == "NULL"} {
                    continue
                }
                if {[$a34_layer getName] != "Metal2"} {
                    continue
                }

                set a34_center_y \
                    [expr {([$a34_box yMin] + [$a34_box yMax]) / 2}]
                set a34_ylo \
                    [expr {$a34_center_y - $a34_bridge_half_width}]
                set a34_yhi \
                    [expr {$a34_center_y + $a34_bridge_half_width}]

                odb::dbSBox_create \
                    $a34_swire $a34_metal3 \
                    0 $a34_ylo $a34_bridge_xmax $a34_yhi \
                    "STRIPE"
            }
        }
    }
}

# Connect the existing fixed Metal2 terminals to the existing
# localized Metal3 bridge shapes.
define_pdn_grid \
    -existing \
    -name a34_existing_power

add_pdn_connect \
    -grid a34_existing_power \
    -layers "Metal2 Metal3"

# Connect the localized Metal3 bridges to the generated Metal4 grid.
add_pdn_connect \
    -grid stdcell_grid \
    -layers "Metal3 Metal4"


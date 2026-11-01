# Writes a sorted, tab-separated text summary of a placed database for comparison:
# die area, every instance (cell, location, orientation, placement status)
# and every net (number of instance and boundary terminals).
# Paths come from A34_DUMP_ODB and A34_DUMP_OUT (set by rebuild_from_rtl.sh).
read_db $::env(A34_DUMP_ODB)
set block [ord::get_db_block]
set rows {}
set die [$block getDieArea]
lappend rows [join [list DIE [$die xMin] [$die yMin] [$die xMax] [$die yMax]] "\t"]
foreach inst [$block getInsts] {
    set loc [$inst getLocation]
    lappend rows [join [list I [$inst getName] [[$inst getMaster] getName] \
        [lindex $loc 0] [lindex $loc 1] [$inst getOrient] [$inst getPlacementStatus]] "\t"]
}
foreach net [$block getNets] {
    lappend rows [join [list N [$net getName] [llength [$net getITerms]] [llength [$net getBTerms]]] "\t"]
}
set out [open $::env(A34_DUMP_OUT) w]
foreach row [lsort $rows] {puts $out $row}
close $out
puts "A34_DUMP_COMPLETE [llength $rows] rows"

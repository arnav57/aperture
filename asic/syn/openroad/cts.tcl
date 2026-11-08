# Stage 3: clock tree synthesis + post-CTS timing repair
source [file dirname [info script]]/common.tcl
load_stage 2_place.odb

estimate_parasitics -placement
repair_clock_inverters

clock_tree_synthesis -sink_clustering_enable -repair_clock_nets
set_propagated_clock [all_clocks]

estimate_parasitics -placement
detailed_placement

repair_timing -verbose
detailed_placement
check_placement -verbose

report_clock_skew
report_design_area
save_stage 3_cts.odb

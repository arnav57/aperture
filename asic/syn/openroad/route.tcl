# Stage 4: global + detailed routing
source [file dirname [info script]]/common.tcl
load_stage 3_cts.odb
set_propagated_clock [all_clocks]

source $PDK/fastroute.tcl

global_route -guide_file $BUILD/route.guide -congestion_iterations 30 -verbose

estimate_parasitics -global_routing
repair_design
global_route -start_incremental
detailed_placement
global_route -end_incremental -congestion_iterations 30

detailed_route \
    -output_drc $BUILD/reports/route_drc.rpt \
    -verbose 1

check_antennas -report_file $BUILD/reports/antennas.rpt
if {![design_is_routed]} { error "design has unrouted nets" }

report_design_area
save_stage 4_route.odb

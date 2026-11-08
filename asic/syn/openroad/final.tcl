# Stage 5: fillers, parasitics, sign-off style reports, DEF/netlist/SDC out
source [file dirname [info script]]/common.tcl
load_stage 4_route.odb
set_propagated_clock [all_clocks]

filler_placement $FILL_CELLS
global_connect
check_placement -verbose

estimate_parasitics -global_routing

set rpt $BUILD/reports
report_checks -path_delay max -group_path_count 5 -fields {slew cap fanout} -digits 3 > $rpt/setup.rpt
report_checks -path_delay min -group_path_count 5 -fields {slew cap fanout} -digits 3 > $rpt/hold.rpt
report_check_types -max_slew -max_capacitance -max_fanout -violators > $rpt/check_types.rpt
report_wns  > $rpt/wns_tns.rpt
report_tns >> $rpt/wns_tns.rpt
report_power > $rpt/power.rpt
report_design_area > $rpt/area.rpt
report_clock_skew > $rpt/clock_skew.rpt

puts "---- final summary ----"
report_wns
report_tns
report_design_area

write_def     $BUILD/${TOP}.def
write_verilog $BUILD/${TOP}_final.v
write_sdc -no_timestamp $BUILD/${TOP}_final.sdc
save_stage 5_final.odb

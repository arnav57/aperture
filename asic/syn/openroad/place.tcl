# Stage 2: global placement, IO placement, resizing, detailed placement
source [file dirname [info script]]/common.tcl
load_stage 1_floorplan.odb

# First pass without IOs so the pin placer has something to optimise against
global_placement -skip_io -density $PLACE_DENSITY
place_pins -hor_layers met3 -ver_layers met2

# Buffer the ports, then the real placement
buffer_ports
global_placement -density $PLACE_DENSITY -routability_driven -timing_driven

estimate_parasitics -placement
repair_design
repair_tie_fanout sky130_fd_sc_hd__conb_1/HI
repair_tie_fanout sky130_fd_sc_hd__conb_1/LO

detailed_placement
check_placement -verbose

report_design_area
save_stage 2_place.odb

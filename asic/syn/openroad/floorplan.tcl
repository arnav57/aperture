# Stage 1: netlist -> floorplan, tracks, tap cells, power grid
source [file dirname [info script]]/common.tcl

load_pdk
read_verilog $BUILD/${TOP}_netlist.v
link_design $TOP
read_sdc $SDC
source $PDK/setRC.tcl

# PDN connectivity rules (VDD/VSS <-> cell power pins)
source $PDK/global_connect.tcl

initialize_floorplan \
    -utilization $UTIL \
    -aspect_ratio 1.0 \
    -core_space 4.0 \
    -site unithd

source $PDK/make_tracks.tcl
source $PDK/fastroute.tcl         ;# routing layer ranges + congestion adjustment

# Well taps, then power grid
source $PDK/tapcell.tcl
global_connect
source $PDK/pdn.tcl
pdngen

report_design_area
save_stage 1_floorplan.odb

# Shared setup, sourced by every stage. Config comes from environment variables set by syn/Makefile.

proc env_or {name default} {
    if {[info exists ::env($name)] && $::env($name) ne ""} { return $::env($name) }
    return $default
}

set TOP      [env_or TOP iris_core]
set BUILD    [file normalize [env_or BUILD build]]
set PDK      [file normalize $::env(PDK_DIR)]
set SDC      [file normalize [env_or SDC [file dirname [info script]]/constraints.sdc]]
set UTIL     [env_or CORE_UTILIZATION 40]      ;# percent
set PLACE_DENSITY [env_or PLACE_DENSITY 0.60]

file mkdir $BUILD/reports

# Variables the sky130hd platform scripts (tapcell.tcl, fastroute.tcl, ...) expect
set ::env(TAP_CELL_NAME)       sky130_fd_sc_hd__tapvpwrvgnd_1
set ::env(MIN_ROUTING_LAYER)   met1
set ::env(MAX_ROUTING_LAYER)   met5
set ::env(MIN_CLK_ROUTING_LAYER) met3

set FILL_CELLS {sky130_fd_sc_hd__fill_1 sky130_fd_sc_hd__fill_2 sky130_fd_sc_hd__fill_4 sky130_fd_sc_hd__fill_8}
set DONT_USE   {sky130_fd_sc_hd__probe_p_8 sky130_fd_sc_hd__probec_p_8 sky130_fd_sc_hd__lpflow_*}

proc load_pdk {} {
    global PDK
    read_liberty $PDK/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
    read_lef     $PDK/lef/sky130_fd_sc_hd.tlef
    read_lef     $PDK/lef/sky130_fd_sc_hd_merged.lef
}

# Open the database written by the previous stage and restore constraints + RC
proc load_stage {odb} {
    global BUILD PDK SDC DONT_USE
    load_pdk
    read_db $BUILD/$odb
    read_sdc $SDC
    source $PDK/setRC.tcl
    set_dont_use $DONT_USE
}

proc save_stage {odb} {
    global BUILD
    write_db $BUILD/$odb
}

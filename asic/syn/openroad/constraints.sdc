# Timing constraints for iris_core. CLK_PERIOD_NS comes from the Makefile (default 6.67 ns = 150 MHz dp_clk).
set clk_period [expr {[info exists ::env(CLK_PERIOD_NS)] ? $::env(CLK_PERIOD_NS) : 6.67}]

create_clock -name clk -period $clk_period [get_ports clk_i]
set_clock_uncertainty 0.15 [get_clocks clk]

# Reset is asynchronous and synchronised outside this block
set_false_path -from [get_ports rstn_i]

# Data ports: 20% of the period of external delay in and out
set data_in [all_inputs -no_clocks]
set_input_delay  [expr {$clk_period * 0.2}] -clock clk $data_in
set_output_delay [expr {$clk_period * 0.2}] -clock clk [all_outputs]

set_driving_cell -lib_cell sky130_fd_sc_hd__buf_2 -pin X $data_in
set_load 0.03 [all_outputs]

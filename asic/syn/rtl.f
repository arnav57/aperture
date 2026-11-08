# RTL for the ASIC-targetable datapath (iris_core). Paths relative to aperture/asic/synth.
# iris_top / iris_pll / ethernet/* are FPGA-only (Altera PLL, verilog-ethernet): not listed.
../design/iris/rtl/iris_byte_align.sv
../design/iris/rtl/iris_core.sv
../design/stf_det/rtl/stf_det.sv
../design/stf_det/rtl/stf_acf.sv
../design/stf_det/rtl/stf_energy.sv
../design/stf_det/rtl/stf_decision.sv
../design/cfo_coarse/rtl/cfo_coarse.sv
../design/cfo_coarse/rtl/cfo_coarse_est.sv
../design/cfo_coarse/rtl/cfo_derotate.sv
../design/math/rtl/cmp_mul.sv
../design/math/rtl/cmp_abs_sq.sv
../design/cordic/rtl/cordic.sv
../design/cordic/rtl/cordic_fold.sv
../design/cordic/rtl/cordic_prefold.sv
../design/cordic/rtl/cordic_pipe.sv
../design/cordic/rtl/cordic_stage.sv
../design/cordic/rtl/cordic_transform.sv

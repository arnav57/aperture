//// Basic Reset Synchronizer (only for active-low)
//// Async assertion of the raw reset; synchronized (clk) release / deassertion.

`timescale 1ns/1ps
`default_nettype none

module std_rstn_sync #(
	parameter int NUM_FLOPS = 3  // Num of sync flops
)(
	input  wire clk_i,
	input  wire rstn_i,   // active-low async reset
	output wire rstn_o    // active-low synchronized reset
);

std_data_sync #(
	.NUM_FLOPS (NUM_FLOPS),
	.RESET_VAL (1'b0)   // level held while raw reset active (0 = asserted)
) I_rst_sync (
	.clk_i  (clk_i),
	.rstn_i (rstn_i),
	.data_i (1'b1),     // deasserted level, pumped through to synchronize release
	.data_o (rstn_o)
);

endmodule : std_rstn_sync

`default_nettype wire

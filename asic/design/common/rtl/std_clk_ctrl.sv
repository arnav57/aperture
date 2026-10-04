// Reusable all-in-one clock control cell. Features the following things
//	-- Integer Clock Division (50% DC for all integers)
//	-- Active low reset synchronization
//  -- Glitch Free Clock Gating (post-division)

`timescale 1ns/1ps
`default_nettype none

module std_clk_ctrl #(
	parameter int NUM_DIV_FLOPS = 4
) (
	input  wire                     clk_i    ,
	input  wire                     rstn_i	 ,

	// Control Inputs
	input  wire                     clk_en_i ,
	input  wire [NUM_DIV_FLOPS-1:0] clk_div_i,

	// Outputs (Free Running + Gated Clks, Synchronized Reset)
	output wire                     clk_fr_o ,
	output wire                     clk_o    ,
	output wire                     rstn_o
);

// Then we generate the free running divided clock
logic clk_fr_int;
std_clk_div #(
    .NUM_DIV_FLOPS(NUM_DIV_FLOPS)
) I_clk_ctrl_clkdiv (
    .clk_i (clk_i),
    .rstn_i(rstn_i),
    .div_i (clk_div_i),
    .clk_o (clk_fr_int)
);

// Reset Synchronizer (on the fr clk)
logic rstn_sync;
std_rstn_sync I_rstn_sync_clk_ctrl (
	.clk_i (clk_fr_int),
	.rstn_i(rstn_i),
	.rstn_o(rstn_sync)
);

// synchronize the clock enable
logic clk_en_s3r;
logic clk_gated_int;


std_data_sync I_data_sync_clk_en_s3r (
    .rstn_i(rstn_sync),
    .clk_i (clk_fr_int),
    .data_i(clk_en_i),
    .data_o(clk_en_s3r)
);

std_clk_gate I_clk_ctrl_clkgate (
    .rstn_i  (rstn_sync),
    .clk_i   (clk_fr_int),
    .clk_o   (clk_gated_int),
    .clk_en_i(clk_en_s3r)
);

// MLIO Assignments
assign clk_fr_o = clk_fr_int;
assign clk_o    = clk_gated_int;
assign rstn_o   = rstn_sync;


endmodule : std_clk_ctrl

`default_nettype wire
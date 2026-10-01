// Basic Clock Gating

`timescale 1ns/1ps
`default_nettype none

module std_clk_gate (
	input  wire clk_i   ,
	input  wire rstn_i  ,
	input  wire clk_en_i, // assumed synchronous to clk_i
	output wire clk_o
);

// update things on the negative edge of the clock so we dont create glitches on posedge logic
	logic gate_l;
	always_latch begin
		if (~rstn_i) begin
			gate_l <= 1'b0;
		end else begin
			if (~clk_i)
				gate_l <= clk_en_i;
		end
	end

	assign clk_o = clk_i & gate_l;

endmodule : std_clk_gate
`default_nettype wire
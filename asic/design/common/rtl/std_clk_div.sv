// standard integer clock divider (50% DC for even and odd integers)

`timescale 1ns/1ps
`default_nettype none

module std_clk_div #(
	parameter int NUM_DIV_FLOPS = 4
) (
	input  wire               		clk_i ,
	input  wire               		rstn_i,
	input  wire [NUM_DIV_FLOPS-1:0] div_i , // expected quasi-static (only change while output clock is unused/gated)
	output wire               		clk_o
);

// flags for clock muxing at the output
	logic div_is_odd, div_is_one;
	assign div_is_odd = div_i[0];
	assign div_is_one = (div_i == NUM_DIV_FLOPS'(0)) || (div_i == NUM_DIV_FLOPS'(1));

// start by creating a generic counter (posedge) counting from 0 to div_i - 1

	logic [NUM_DIV_FLOPS-1:0] cnt_r;

	logic cnt_at_max;
	assign cnt_at_max = (cnt_r >= div_i - 1'b1) || div_is_one;

	always_ff @(posedge clk_i, negedge rstn_i) begin
		if(~rstn_i) begin
			cnt_r <= NUM_DIV_FLOPS'(0);
		end else begin
			cnt_r <= (cnt_at_max) ? NUM_DIV_FLOPS'(0) : cnt_r + NUM_DIV_FLOPS'(1);
		end
	end

// Then we can derive a clk_p from this
// note that we flop clk_p here so the pos -> negedge sampling is cleab
	logic [NUM_DIV_FLOPS-1:0] cnt_half;
	assign cnt_half = div_i >> 1;

	logic clk_p;
	always_ff @(posedge clk_i, negedge rstn_i) begin
		if(~rstn_i) begin
			clk_p <= 0;
		end else begin
			clk_p <= (cnt_r < cnt_half);
		end
	end

// then we sample this clk_p on the negedge to delay it by 0.5 a period
	logic clk_n;
	always_ff @(negedge clk_i, negedge rstn_i) begin
		if (~rstn_i) begin
			clk_n <= 1'd0;
		end else begin
			clk_n <= clk_p;
		end
	end

// mux between even/odd clocks and also bypass the divided clock if we want passthru
	logic clk_divided;
	assign clk_divided = (div_is_odd) ? (clk_p | clk_n) : clk_p;
	assign clk_o       = (div_is_one) ? clk_i           : clk_divided;


endmodule : std_clk_div
`default_nettype wire
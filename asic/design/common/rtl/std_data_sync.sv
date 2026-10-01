//// Basic Data (single-bit) Synchronizer 

`timescale 1ns/1ps
`default_nettype none

module std_data_sync #(
	parameter int   NUM_FLOPS = 3,     // Number of synchronizer flops
	parameter logic RESET_VAL = 1'b0  // 1-bit reset value (level held while reset active)
) (
	input  wire clk_i, 
	input  wire rstn_i,
	input  wire data_i,
	output wire data_o
);

logic [NUM_FLOPS-1:0] flop_r;

// chain NUM_FLOPS flops together
always_ff @(posedge clk, negedge rstn_i) begin
	if(~rstn_i) begin
		flop_r <= {NUM_FLOPS{RESET_VAL}};
	end else begin
		flop_r[0] <= data_i;
		for (int i = 1; i < NUM_FLOPS; i++) begin
			flop_r[i] <= flop_r[i-1];
		end
	end
end

assign data_o = flop_r[NUM_FLOPS-1];

endmodule : std_data_sync

`default_nettype wire

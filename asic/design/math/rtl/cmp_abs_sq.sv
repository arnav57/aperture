`timescale 1ns/1ps
`default_nettype none


module cmp_abs_sq #(
    parameter INPUT_WIDTH = 16
) (
    input wire clk_i,
    input wire rstn_i,

    // input is X + jY
    input wire signed [INPUT_WIDTH-1:0] X_i,
    input wire signed [INPUT_WIDTH-1:0] Y_i,

    // output is Z^2 = X^2 + Y^2
    output wire [2*INPUT_WIDTH:0] Z_o
);

    localparam MUL_WIDTH = 2 * INPUT_WIDTH;
    localparam ADD_WIDTH = MUL_WIDTH + 1;

    logic signed [MUL_WIDTH-1:0] x_sq_r;
    logic signed [MUL_WIDTH-1:0] y_sq_r;
    logic signed [ADD_WIDTH-1:0] abs_sq_r;
    
    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            x_sq_r   <= MUL_WIDTH'(0);
            y_sq_r   <= MUL_WIDTH'(0);
            abs_sq_r <= ADD_WIDTH'(0);
        end else begin
            x_sq_r   <= X_i * X_i;
            y_sq_r   <= Y_i * Y_i;
            abs_sq_r <= x_sq_r + y_sq_r;
        end
    end

    assign Z_o = abs_sq_r;

endmodule : cmp_abs_sq

`default_nettype wire

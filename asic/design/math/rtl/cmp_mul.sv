`timescale 1ns/1ps
`default_nettype none

module cmp_mul #(
    parameter int INPUT_WIDTH = 8
) ( 
    // first operand is a + jb;
    input wire signed [INPUT_WIDTH-1:0] a_i,
    input wire signed [INPUT_WIDTH-1:0] b_i,

    // second operand is c + jd
    input wire signed [INPUT_WIDTH-1:0] c_i,
    input wire signed [INPUT_WIDTH-1:0] d_i,

    // outputs are x + jy
    output wire signed [2*INPUT_WIDTH:0] x_o,
    output wire signed [2*INPUT_WIDTH:0] y_o
);

    // TODO: Optimize this shit later

    logic signed [2*INPUT_WIDTH:0] ac;
    logic signed [2*INPUT_WIDTH:0] bd;
    logic signed [2*INPUT_WIDTH:0] bc;
    logic signed [2*INPUT_WIDTH:0] ad;

    logic signed [2*INPUT_WIDTH:0] x;
    logic signed [2*INPUT_WIDTH:0] y;

    assign ac = a_i * c_i;
    assign bd = b_i * d_i;
    assign bc = b_i * c_i;
    assign ad = a_i * d_i;

    assign x_o = (ac - bd);
    assign y_o = (bc + ad);

endmodule : cmp_mul

`default_nettype wire
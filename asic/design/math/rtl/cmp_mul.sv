`timescale 1ns/1ps
`default_nettype none

module cmp_mul #(
    parameter int INPUT_WIDTH = 16
) ( 
    input wire clk_i,
    input wire rstn_i,

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

    // Sign Extensions
    logic signed [INPUT_WIDTH:0] a_ext, b_ext, c_ext, d_ext;
    assign a_ext = { a_i[INPUT_WIDTH-1], a_i[INPUT_WIDTH-1:0] }; 
    assign b_ext = { b_i[INPUT_WIDTH-1], b_i[INPUT_WIDTH-1:0] }; 
    assign c_ext = { c_i[INPUT_WIDTH-1], c_i[INPUT_WIDTH-1:0] }; 
    assign d_ext = { d_i[INPUT_WIDTH-1], d_i[INPUT_WIDTH-1:0] }; 

    // Additions
    logic signed [INPUT_WIDTH:0] a_add_b;
    logic signed [INPUT_WIDTH:0] c_add_d;
    assign a_add_b = a_ext + b_ext;
    assign c_add_d = c_ext + d_ext;

    // Pipelined Multiplication
    always_ff @( posedge clk_i, negedge rstn_i ) begin
        if (~rstn_i) begin

        end else begin

        end
    end

endmodule : cmp_mul

`default_nettype wire
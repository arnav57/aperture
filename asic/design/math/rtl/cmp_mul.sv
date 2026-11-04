`timescale 1ns/1ps
`default_nettype none

module cmp_mul #(
    parameter int INPUT_WIDTH = 16,
    parameter bit CONJ_CD = 1'b0 // if this is 1 we do (a + jb) * (c - jd) instead
) (
    input wire clk_i,
    input wire rstn_i,

    // (a + jb) * (c + jd) = x + jy
    input wire signed [INPUT_WIDTH-1:0] a_i,
    input wire signed [INPUT_WIDTH-1:0] b_i,
    input wire signed [INPUT_WIDTH-1:0] c_i,
    input wire signed [INPUT_WIDTH-1:0] d_i,

    output logic signed [2*INPUT_WIDTH:0] x_o,
    output logic signed [2*INPUT_WIDTH:0] y_o
);
    localparam int PROD_WIDTH = 2*INPUT_WIDTH + 1;

    // Stage 1: pre-adders + operand delay
    logic signed [INPUT_WIDTH:0]   a_add_b_r, m2_r, m3_r;  // a+b, d-c, c+d
    logic signed [INPUT_WIDTH-1:0] a_d1r, b_d1r, c_d1r;

    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            a_add_b_r <= 'd0;
            m2_r <= 'd0;
            m3_r <= 'd0;
            a_d1r <= 'd0;
            b_d1r <= 'd0;
            c_d1r <= 'd0;
        end else begin
            a_add_b_r <= a_i + b_i;
            m2_r <= CONJ_CD ? (c_i + d_i) : (d_i - c_i);
            m3_r <= CONJ_CD ? (c_i - d_i) : (c_i + d_i);
            a_d1r     <= a_i;
            b_d1r     <= b_i;
            c_d1r     <= c_i;
        end
    end

    // Stage 2: multiplies
    logic signed [PROD_WIDTH-1:0] p1_r, p2_r, p3_r;

    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            p1_r <= 'd0;
            p2_r <= 'd0;
            p3_r <= 'd0;
        end else begin
            p1_r <= c_d1r * a_add_b_r;   // c(a+b)
            p2_r <= a_d1r * m2_r;   // a(d-c)
            p3_r <= b_d1r * m3_r;   // b(c+d)
        end
    end

    // Stage 3: post-adders
    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            x_o <= 'd0;
            y_o <= 'd0;
        end else begin
            x_o <= p1_r - p3_r;      // ac - bd
            y_o <= CONJ_CD ? (p1_r - p2_r) : (p1_r + p2_r);      // ad + bc
        end
    end

endmodule : cmp_mul

`default_nettype wire
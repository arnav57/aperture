`timescale 1ns/1ps
`default_nettype none

module cfo_coarse(
    input wire clk_i,
    input wire rstn_i,

    // raw sample strewam
    input wire signed [15:0] I_i,
    input wire signed [15:0] Q_i,
    input wire               IQ_valid_i,

    // from stf_det
    input wire               stf_det_i,
    input wire signed [35:0] acf_re_i,
    input wire signed [35:0] acf_im_i,
    input wire               acf_valid_i,

    // derotated samples out
    output wire signed [15:0] I_o,
    output wire signed [15:0] Q_o,
    output wire               IQ_valid_o
);

    logic signed [15:0] cfo_angle;
    logic               cfo_valid;

    cfo_coarse_est I_cfo_coarse_est (
    	.clk_i      (clk_i),
    	.rstn_i     (rstn_i),
    	.stf_det_i  (stf_det_i),
    	.acf_re_i   (acf_re_i),
    	.acf_im_i   (acf_im_i),
    	.acf_valid_i(acf_valid_i),
    	.cfo_angle_o(cfo_angle),
    	.cfo_valid_o(cfo_valid)
    );

    cfo_derotate I_cfo_derotate (
    	.clk_i      (clk_i),
    	.rstn_i     (rstn_i),
    	.I_i        (I_i),
    	.Q_i        (Q_i),
    	.IQ_valid_i (IQ_valid_i),
    	.cfo_angle_i(cfo_angle),
    	.cfo_valid_i(cfo_valid),
    	.I_o        (I_o),
    	.Q_o        (Q_o),
    	.IQ_valid_o (IQ_valid_o)
    );

endmodule : cfo_coarse

`default_nettype wire

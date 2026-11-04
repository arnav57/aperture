/// Schmidl-Cox style autocorrelator

`timescale 1ns/1ps
`default_nettype none

module stf_det (
    input wire clk_i,
    input wire rstn_i,

    // Aligned IQ Stream
    input wire signed [15:0] I_i,
    input wire signed [15:0] Q_i,
    input wire signed        IQ_valid_i
);

///////////////////////////////////////////////////////
/// This blocks job is to detect the OFDM packets STF,
///
/// This algorithm requires three things to work
///    1. Autocorrelator with lag of 16
///    2. Current Signal Energy
///    3. A Decision Metric based on (1) and (2)
///////////////////////////////////////////////////////

    logic signed [35:0] acf_raw_re;
    logic signed [35:0] acf_raw_im;

    logic signed [35:0] acf_abs_re;
    logic signed [35:0] acf_abs_im;

    stf_acf I_stf_acf (
        .clk_i ( clk_i ),
        .rstn_i ( rstn_i ),


        .I_i (I_i) ,
        .Q_i (Q_i),
        .valid_i (IQ_valid_i),

        .acf_re_o(acf_raw_re),
        .acf_im_o(acf_raw_im)
    );

    assign acf_abs_re = acf_raw_re[35] ? -acf_raw_re : acf_raw_re;
    assign acf_abs_im = acf_raw_im[35] ? -acf_raw_im : acf_raw_im;

    logic signed [36:0] acf_mag;
    assign acf_mag = acf_abs_re + acf_abs_im;
    
endmodule : stf_det
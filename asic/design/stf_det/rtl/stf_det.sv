/// Schmidl-Cox style autocorrelator

`timescale 1ns/1ps
`default_nettype none

module stf_det (
    input wire clk_i,
    input wire rstn_i,

    // Aligned IQ Stream
    input wire signed [15:0] I_i,
    input wire signed [15:0] Q_i,
    input wire               IQ_valid_i,

    // STF Detect Flag
    output wire stf_det_o
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

    logic signed [15:0] I_d16;
    logic signed [15:0] Q_d16;

    logic signed [35:0] energy;

/// Lag 16 Autocorrelator + Delay Line
    stf_acf I_stf_acf (
        .clk_i ( clk_i ),
        .rstn_i ( rstn_i ),
        // input IQ bus
        .I_i (I_i) ,
        .Q_i (Q_i),
        .IQ_valid_i (IQ_valid_i),
        // autocorrelation out
        .acf_re_o(acf_raw_re),
        .acf_im_o(acf_raw_im),
        // To stf_energy
        .I_d16_o(I_d16),
        .Q_d16_o(Q_d16)
    );

/// Current Signal Energy
    stf_energy I_stf_energy (
        .clk_i ( clk_i ),
        .rstn_i ( rstn_i ),
        // input IQ bus
        .I_i (I_i) ,
        .Q_i (Q_i),
        .IQ_valid_i (IQ_valid_i),
        .I_d16_i (I_d16),
        .Q_d16_i (Q_d16),
        // Energy
        .E_o ( energy )
    );

/// STF Detection Proposal
    stf_decision I_stf_decision (
    	.clk_i    (clk_i),
    	.rstn_i   (rstn_i),
        // from stf_acf
    	.acf_re_i (acf_raw_re),
    	.acf_im_i (acf_raw_im),
        // from stf_energy
    	.energy_i (energy),
    	.stf_det_o(stf_det_o)
    );


endmodule : stf_det

`default_nettype wire

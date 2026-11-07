`timescale 1ns/1ps
`default_nettype none

module iris_core (
    input wire       clk_i,
    input wire       rstn_i,

    // ENET1 Data
    input wire       enet1_rx_tvalid,
    input wire [7:0] enet1_rx_tdata,
    input wire       enet1_rx_tlast

);
    // Byte Aligner Outputs
    logic signed [15:0] i;
    logic signed [15:0] q;
    logic              iq_valid;

    // stf_det outputs
    logic signed [35:0] acf_stf_re;
    logic signed [35:0] acf_stf_im;
    logic               acf_stf_valid;
    logic               stf_det;

    // cfo_coarse outputs
    logic signed [15:0] i_derot, q_derot;
    logic               iq_derot_valid;

/// Byte Aligner
    iris_byte_align I_byte_align (
        .clk_i              ( clk_i             ),
        .rstn_i             ( rstn_i            ),
        .tvalid_i           ( enet1_rx_tvalid   ),
        .tdata_i            ( enet1_rx_tdata    ),
        .tlast_i            ( enet1_rx_tlast    ),
        .I_o                ( i                 ),
        .Q_o                ( q                 ),
        .valid_o            ( iq_valid          )
    );

/// STF Detect
    stf_det I_stf_det (
        .clk_i      ( clk_i    ),
        .rstn_i     ( rstn_i   ),
        .I_i        ( i        ),
        .Q_i        ( q        ),
        .IQ_valid_i ( iq_valid ),
       	.acf_re_o   (acf_stf_re),
        .acf_im_o   (acf_stf_im),
        .acf_valid_o(acf_stf_valid),
        .stf_det_o  (stf_det)
    );

/// Find + Correct Coarse CFO
    cfo_coarse cfo_coarse (
    	.clk_i      (clk_i),
    	.rstn_i     (rstn_i),
    	.I_i        (i),
    	.Q_i        (q),
    	.IQ_valid_i (iq_valid),
    	.stf_det_i  (stf_det),
    	.acf_re_i   (acf_stf_re),
    	.acf_im_i   (acf_stf_im),
    	.acf_valid_i(acf_stf_valid),
    	.I_o        (i_derot),
    	.Q_o        (q_derot),
    	.IQ_valid_o (iq_derot_valid)
    );



endmodule : iris_core

`default_nettype wire

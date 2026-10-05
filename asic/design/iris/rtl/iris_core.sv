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

    logic signed [7:0] i;
    logic signed [7:0] q;
    logic              iq_valid;


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



endmodule : iris_core

`default_nettype wire
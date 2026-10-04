`timescale 1ns/1ps
`default_nettype none

module iris_top (

    // Main Refclk and ASIC Reset
    input wire         refclk_i,
    input wire         rstn_i,

    // Status Out
    output wire        pll_lock_o,

    // RGMII Pins
	output wire        ENET1_GTX_CLK     ,
	output wire        ENET1_TX_EN       ,
	output wire [3:0]  ENET1_TX_DATA     ,
	input  wire        ENET1_RX_CLK      ,
	input  wire        ENET1_RX_DV       ,
	input  wire [3:0]  ENET1_RX_DATA

);  


/// Clock + Reset Generation

    logic eth_clk_main, eth_clk_shift, dp_clk;
    logic rstn_eth_clk, rstn_dp_clk;

    iris_clkgen I_clkgen (
        .refclk_i        ( refclk_i      ),
        .rstn_i          ( rstn_i        ),
        .eth_clk_main_o  ( eth_clk_main  ),
        .eth_clk_shift_o ( eth_clk_shift ),
        .dp_clk_o        ( dp_clk        ),
        .rstn_eth_clk_o  ( rstn_eth_clk  ),
        .rstn_dp_clk_o   ( rstn_dp_clk   ),
        .pll_lock_o      ( pll_lock_o    )
    );

/// Ethernet 1 Stack

    axis_if udp_rx_stream (.clk(dp_clk), .rstn(rstn_dp_clk));
    axis_if udp_tx_stream (.clk(dp_clk), .rstn(rstn_dp_clk));
    assign udp_rx_stream.tready = 1'b1;

    ethernet I_enet_1 (
        // Clocks and Resets
        .clk_125_i          ( eth_clk_main  ),
        .clk_125_90_i       ( eth_clk_shift ),
        .rstn_clk_125_i     ( rstn_eth_clk  ),
        .compute_clk_i      ( dp_clk        ),
        .rstn_compute_clk_i ( rstn_dp_clk   ),
        // AXI-S i/f from Ethernet 1 MAC
        .udp_rx_tdata       ( udp_rx_stream.tdata  ),
        .udp_rx_tvalid      ( udp_rx_stream.tvalid ),
        .udp_rx_tready      ( udp_rx_stream.tready ),
        .udp_rx_tlast       ( udp_rx_stream.tlast  ),
        .udp_rx_tuser       ( udp_rx_stream.tuser  ),
        // AXI-S i/f to Ethernet 1 MAC
        .udp_tx_tdata       ( udp_tx_stream.tdata  ),
        .udp_tx_tvalid      ( udp_tx_stream.tvalid ),
        .udp_tx_tready      ( udp_tx_stream.tready ),
        .udp_tx_tlast       ( udp_tx_stream.tlast  ),
        .udp_tx_tuser       ( udp_tx_stream.tuser  ),
        // Top Level ENET1 Pins 
        .ENET1_GTX_CLK      ( ENET1_GTX_CLK ),
        .ENET1_TX_EN        ( ENET1_TX_EN   ),
        .ENET1_TX_DATA      ( ENET1_TX_DATA ),
        .ENET1_RX_CLK       ( ENET1_RX_CLK  ),
        .ENET1_RX_DV        ( ENET1_RX_DV   ),
        .ENET1_RX_DATA      ( ENET1_RX_DATA )
    );

endmodule : iris_top

`default_nettype wire
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
        .refclk_i               ( refclk_i              ),
        .rstn_i                 ( rstn_i                ),
        .eth_clk_main_o         ( eth_clk_main          ),
        .eth_clk_shift_o        ( eth_clk_shift         ),
        .dp_clk_o               ( dp_clk                ),
        .rstn_eth_clk_o         ( rstn_eth_clk          ),
        .rstn_dp_clk_o          ( rstn_dp_clk           ),
        .pll_lock_o             ( pll_lock_o            )
    );

/// Ethernet 1 Stack

    logic [7:0] enet1_rx_tdata;
    logic       enet1_rx_tvalid, enet1_rx_tlast;

    ethernet I_enet_1 (
        // Clocks and Resets
        .clk_125_i          ( eth_clk_main          ),
        .clk_125_90_i       ( eth_clk_shift         ),
        .rstn_clk_125_i     ( rstn_eth_clk          ),
        .compute_clk_i      ( dp_clk                ),
        .rstn_compute_clk_i ( rstn_dp_clk           ),
        // AXI-S i/f from Ethernet 1 MAC
        .udp_rx_tdata       ( enet1_rx_tdata        ),
        .udp_rx_tvalid      ( enet1_rx_tvalid       ),
        .udp_rx_tready      ( 1'b1                  ),
        .udp_rx_tlast       ( enet1_rx_tlast        ),
        .udp_rx_tuser       ( /* FLOATING */        ),
        // AXI-S i/f to Ethernet 1 MAC
        .udp_tx_tdata       ( /* FLOATING */        ),
        .udp_tx_tvalid      ( /* FLOATING */        ),
        .udp_tx_tready      ( /* FLOATING */        ),
        .udp_tx_tlast       ( /* FLOATING */        ),
        .udp_tx_tuser       ( /* FLOATING */        ),
        // Top Level ENET1 Pins 
        .ENET1_GTX_CLK      ( ENET1_GTX_CLK         ),
        .ENET1_TX_EN        ( ENET1_TX_EN           ),
        .ENET1_TX_DATA      ( ENET1_TX_DATA         ),
        .ENET1_RX_CLK       ( ENET1_RX_CLK          ),
        .ENET1_RX_DV        ( ENET1_RX_DV           ),
        .ENET1_RX_DATA      ( ENET1_RX_DATA         )
    );

/// Iris Core 
    iris_core I_core (
        .clk_i              ( dp_clk                    ),
        .rstn_i             ( rstn_dp_clk               ),
        .enet1_rx_tdata     ( enet1_rx_tdata            ),
        .enet1_rx_tvalid    ( enet1_rx_tvalid           ),
        .enet1_rx_tlast     ( enet1_rx_tlast            )
    );      

endmodule : iris_top

`default_nettype wire
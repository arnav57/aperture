`resetall
`timescale 1ns/1ps
`default_nettype none

module ethernet_mac (
	// GbE clocks are 125M and 90 deg shifted variants
	input  wire       clk_125_i     ,
	input  wire       clk_125_90_i  ,
	input  wire       rstn_clk_125_i,

	// Our Logic clock
	input wire 		 compute_clk_i,
	input wire 		 rstn_compute_clk_i,

	// AXI-S interfaces to MAC
	axis_if.master    mac_rx_stream , // Data from MAC to us
	axis_if.slave     mac_tx_stream , // Data from us to MAC

	// RGMII Pins
	output wire       enet1_gtx_clk ,
	output wire       enet1_tx_en   ,
	output wire [3:0] enet1_tx_data ,
	input  wire       enet1_rx_clk  ,
	input  wire       enet1_rx_dv   ,
	input  wire [3:0] enet1_rx_data
);

////////////////// ETHERNET MAC //////////////////

eth_mac_1g_rgmii_fifo #(
        .TARGET("ALTERA"),       // Target platform is the de2-115 (altera)
        .IODDR_STYLE("IODDR2"),  // Specific to Cyclone IV (we use cyclone IV E)
        .USE_CLK90("TRUE"),
        .AXIS_DATA_WIDTH(8)
) I_eth_mac_fifo (
    .gtx_clk(clk_125_i),
    .gtx_clk90(clk_125_90_i),
    .gtx_rst(~rstn_clk_125_i),

    // this is the stff for the recieving CDC
    .logic_clk(compute_clk_i),
    .logic_rst(~rstn_compute_clk_i),
    
    // Physical Pins
    .rgmii_rx_clk(enet1_rx_clk),
    .rgmii_rxd(enet1_rx_data),
    .rgmii_rx_ctl(enet1_rx_dv),
    .rgmii_tx_clk(enet1_gtx_clk),
    .rgmii_txd(enet1_tx_data),
    .rgmii_tx_ctl(enet1_tx_en),
    
    // Connect things to the interfaces
    .rx_axis_tdata(mac_rx_stream.tdata),
    .rx_axis_tvalid(mac_rx_stream.tvalid),
    .rx_axis_tready(mac_rx_stream.tready),
    .rx_axis_tlast(mac_rx_stream.tlast),
    .rx_axis_tuser(mac_rx_stream.tuser),
    // .rx_axis_tkeep(1'b1), Unused for 8b dp
    
    .tx_axis_tdata(mac_tx_stream.tdata),
    .tx_axis_tvalid(mac_tx_stream.tvalid),
    .tx_axis_tready(mac_tx_stream.tready),
    .tx_axis_tlast(mac_tx_stream.tlast),
    .tx_axis_tuser(mac_tx_stream.tuser),
    .tx_axis_tkeep(1'b1), // Unused for 8b dp, but set to all 1's for completeness
    
    // Boilerplate Config
    .cfg_ifg(8'd12),
    .cfg_tx_enable(1'b1),
    .cfg_rx_enable(1'b1)
);


endmodule : ethernet_mac
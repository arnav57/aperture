`resetall
`timescale 1ns/1ps
`default_nettype none

module ethernet (
	input  wire        clk_125_i         ,
	input  wire        clk_125_90_i      ,
	input  wire        rstn_clk_125_i    ,

	// Our Logic clock
	input  wire        compute_clk_i     ,
	input  wire        rstn_compute_clk_i,

	// UDP RX stream (data from MAC to us)
	output wire [7:0]  udp_rx_tdata      ,
	output wire        udp_rx_tvalid     ,
	input  wire        udp_rx_tready     ,
	output wire        udp_rx_tlast      ,
	output wire        udp_rx_tuser      ,

	// UDP TX stream (data from us to MAC)
	input  wire [7:0]  udp_tx_tdata      ,
	input  wire        udp_tx_tvalid     ,
	output wire        udp_tx_tready     ,
	input  wire        udp_tx_tlast      ,
	input  wire        udp_tx_tuser      ,

	// RGMII Pins
	output wire        ENET1_GTX_CLK     ,
	output wire        ENET1_TX_EN       ,
	output wire [ 3:0] ENET1_TX_DATA     ,
	input  wire        ENET1_RX_CLK      ,
	input  wire        ENET1_RX_DV       ,
	input  wire [ 3:0] ENET1_RX_DATA
);

axis_if udp_rx_stream (.clk(compute_clk_i), .rstn(rstn_compute_clk_i));
axis_if udp_tx_stream (.clk(compute_clk_i), .rstn(rstn_compute_clk_i));

// Core drives the RX stream, we drive tready
assign udp_rx_tdata        = udp_rx_stream.tdata;
assign udp_rx_tvalid       = udp_rx_stream.tvalid;
assign udp_rx_tlast        = udp_rx_stream.tlast;
assign udp_rx_tuser        = udp_rx_stream.tuser;
assign udp_rx_stream.tready = udp_rx_tready;

// We drive the TX stream, core drives tready
assign udp_tx_stream.tdata  = udp_tx_tdata;
assign udp_tx_stream.tvalid = udp_tx_tvalid;
assign udp_tx_stream.tlast  = udp_tx_tlast;
assign udp_tx_stream.tuser  = udp_tx_tuser;
assign udp_tx_tready        = udp_tx_stream.tready;

ethernet_core I_eth_core (
	.clk_125_i         (clk_125_i         ),
	.clk_125_90_i      (clk_125_90_i      ),
	.rstn_clk_125_i    (rstn_clk_125_i    ),
	.compute_clk_i     (compute_clk_i     ),
	.rstn_compute_clk_i(rstn_compute_clk_i),
	.udp_rx_stream     (udp_rx_stream     ),
	.udp_tx_stream     (udp_tx_stream     ),
	.enet1_gtx_clk     (ENET1_GTX_CLK     ),
	.enet1_tx_en       (ENET1_TX_EN       ),
	.enet1_tx_data     (ENET1_TX_DATA     ),
	.enet1_rx_clk      (ENET1_RX_CLK      ),
	.enet1_rx_dv       (ENET1_RX_DV       ),
	.enet1_rx_data     (ENET1_RX_DATA     )
);

endmodule : ethernet

`default_nettype wire
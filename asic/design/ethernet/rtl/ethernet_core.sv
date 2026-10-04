`resetall
`timescale 1ns/1ps
`default_nettype none

module ethernet_core (
	input  wire        clk_125_i         ,
	input  wire        clk_125_90_i      ,
	input  wire        rstn_clk_125_i    ,

	// Our Logic clock
	input  wire        compute_clk_i     ,
	input  wire        rstn_compute_clk_i,

	// AXI-S interfaces to MAC
	axis_if.master     udp_rx_stream     , // Data from MAC to us
	axis_if.slave      udp_tx_stream     , // Data from us to MAC

	// RGMII Pins
	output wire        enet1_gtx_clk     ,
	output wire        enet1_tx_en       ,
	output wire [ 3:0] enet1_tx_data     ,
	input  wire        enet1_rx_clk      ,
	input  wire        enet1_rx_dv       ,
	input  wire [ 3:0] enet1_rx_data
);

// Local Signals
wire        tx_eth_hdr_ready;
wire        tx_eth_hdr_valid;
wire [47:0] tx_eth_dest_mac;
wire [47:0] tx_eth_src_mac;
wire [15:0] tx_eth_type;
wire [7:0]  tx_eth_payload_tdata;
wire        tx_eth_payload_tvalid;
wire        tx_eth_payload_tready;
wire        tx_eth_payload_tlast;
wire        tx_eth_payload_tuser;

wire        rx_eth_hdr_ready;
wire        rx_eth_hdr_valid;
wire [47:0] rx_eth_dest_mac;
wire [47:0] rx_eth_src_mac;
wire [15:0] rx_eth_type;
wire [7:0]  rx_eth_payload_tdata;
wire        rx_eth_payload_tvalid;
wire        rx_eth_payload_tready;
wire        rx_eth_payload_tlast;
wire        rx_eth_payload_tuser;

wire        udp_hdr_valid;
wire        udp_hdr_ready;
wire [31:0] udp_ip_source_ip;
wire [31:0] udp_ip_dest_ip;
wire [15:0] udp_source_port;
wire [15:0] udp_dest_port;
wire [15:0] udp_length;

wire [7:0]  udp_payload_tdata;
wire        udp_payload_tvalid;
wire        udp_payload_tready;
wire        udp_payload_tlast;
wire        udp_payload_tuser;

// Local AXI-S Interfaces
axis_if mac_rx_stream (.clk(compute_clk_i), .rstn(rstn_compute_clk_i));
axis_if mac_tx_stream (.clk(compute_clk_i), .rstn(rstn_compute_clk_i));


/////// ETHERNET MAC INSTANCE

ethernet_mac I_eth_mac (
	.clk_125_i         (clk_125_i         ),
	.clk_125_90_i      (clk_125_90_i      ),
	.rstn_clk_125_i    (rstn_clk_125_i    ),
	.compute_clk_i     (compute_clk_i     ),
	.rstn_compute_clk_i(rstn_compute_clk_i),
	.mac_rx_stream     (mac_rx_stream     ), // Data from MAC to us
	.mac_tx_stream     (mac_tx_stream     ), // Data from us to MAC
	.enet1_gtx_clk     (enet1_gtx_clk     ),
	.enet1_tx_en       (enet1_tx_en       ),
	.enet1_tx_data     (enet1_tx_data     ),
	.enet1_rx_clk      (enet1_rx_clk      ),
	.enet1_rx_dv       (enet1_rx_dv       ),
	.enet1_rx_data     (enet1_rx_data     )
);

/////// ETHERNET MAC RX

eth_axis_rx eth_rx_inst (
    .clk(compute_clk_i),
    .rst(~rstn_compute_clk_i),
    
    // Unpack MAC RX interface
    .s_axis_tdata  (mac_rx_stream.tdata),
    .s_axis_tvalid (mac_rx_stream.tvalid),
    .s_axis_tready (mac_rx_stream.tready),
    .s_axis_tlast  (mac_rx_stream.tlast),
    .s_axis_tuser  (mac_rx_stream.tuser),
    
    // To UDP Stack
    .m_eth_hdr_valid(rx_eth_hdr_valid),
    .m_eth_hdr_ready(rx_eth_hdr_ready),
    .m_eth_dest_mac(rx_eth_dest_mac),
    .m_eth_src_mac(rx_eth_src_mac),
    .m_eth_type(rx_eth_type),
    .m_eth_payload_axis_tdata(rx_eth_payload_tdata),
    .m_eth_payload_axis_tkeep(), // Ignore
    .m_eth_payload_axis_tvalid(rx_eth_payload_tvalid),
    .m_eth_payload_axis_tready(rx_eth_payload_tready),
    .m_eth_payload_axis_tlast(rx_eth_payload_tlast),
    .m_eth_payload_axis_tuser(rx_eth_payload_tuser),
    
    .busy(),
    .error_header_early_termination()
);

/////// ETHERNET MAC TX

eth_axis_tx eth_tx_inst (
        .clk(compute_clk_i),
        .rst(~rstn_compute_clk_i),
        
        // Input from UDP Stack
        .s_eth_hdr_valid(tx_eth_hdr_valid),
        .s_eth_hdr_ready(tx_eth_hdr_ready),
        .s_eth_dest_mac(tx_eth_dest_mac),
        .s_eth_src_mac(tx_eth_src_mac),
        .s_eth_type(tx_eth_type),
        .s_eth_payload_axis_tdata(tx_eth_payload_tdata),
        .s_eth_payload_axis_tkeep(1'b1),
        .s_eth_payload_axis_tvalid(tx_eth_payload_tvalid),
        .s_eth_payload_axis_tready(tx_eth_payload_tready),
        .s_eth_payload_axis_tlast(tx_eth_payload_tlast),
        .s_eth_payload_axis_tuser(tx_eth_payload_tuser),
        
        // Pack into MAC TX interface
        .m_axis_tdata  (mac_tx_stream.tdata),   
        .m_axis_tvalid (mac_tx_stream.tvalid),
        .m_axis_tready (mac_tx_stream.tready),
        .m_axis_tlast  (mac_tx_stream.tlast),
        .m_axis_tuser  (mac_tx_stream.tuser),
        .m_axis_tkeep  () // ignore
);

///////// UDP STACK
udp_complete udp_inst (
    .clk(compute_clk_i),
    .rst(~rstn_compute_clk_i),
    
    // Ethernet Frame Input
    .s_eth_hdr_valid(rx_eth_hdr_valid),
    .s_eth_hdr_ready(rx_eth_hdr_ready),
    .s_eth_dest_mac(rx_eth_dest_mac),
    .s_eth_src_mac(rx_eth_src_mac),
    .s_eth_type(rx_eth_type),
    .s_eth_payload_axis_tdata(rx_eth_payload_tdata),
    .s_eth_payload_axis_tvalid(rx_eth_payload_tvalid),
    .s_eth_payload_axis_tready(rx_eth_payload_tready),
    .s_eth_payload_axis_tlast(rx_eth_payload_tlast),
    .s_eth_payload_axis_tuser(rx_eth_payload_tuser),
    
    // Ethernet Frame Output
    .m_eth_hdr_valid(tx_eth_hdr_valid),
    .m_eth_hdr_ready(tx_eth_hdr_ready),
    .m_eth_dest_mac(tx_eth_dest_mac),
    .m_eth_src_mac(tx_eth_src_mac),
    .m_eth_type(tx_eth_type),
    .m_eth_payload_axis_tdata(tx_eth_payload_tdata),
    .m_eth_payload_axis_tvalid(tx_eth_payload_tvalid),
    .m_eth_payload_axis_tready(tx_eth_payload_tready),
    .m_eth_payload_axis_tlast(tx_eth_payload_tlast),
    .m_eth_payload_axis_tuser(tx_eth_payload_tuser),

    //// Tying off unused application payloads
    // We only care about UDP
    .m_ip_hdr_ready(1'b1),
    .m_ip_payload_axis_tready(1'b1),
    .s_ip_hdr_valid(1'b0),
    .s_ip_payload_axis_tvalid(1'b0),

    .m_udp_hdr_valid(udp_hdr_valid),
    .m_udp_hdr_ready(udp_hdr_ready),
    .m_udp_ip_source_ip(udp_ip_source_ip),
    .m_udp_ip_dest_ip(udp_ip_dest_ip),
    .m_udp_source_port(udp_source_port),
    .m_udp_dest_port(udp_dest_port),
    .m_udp_length(udp_length),
    
    .m_udp_payload_axis_tdata(udp_rx_stream.tdata),
    .m_udp_payload_axis_tvalid(udp_rx_stream.tvalid),
    .m_udp_payload_axis_tready(udp_rx_stream.tready),
    .m_udp_payload_axis_tlast(udp_rx_stream.tlast),
    .m_udp_payload_axis_tuser(udp_rx_stream.tuser),

    .s_udp_hdr_valid(udp_hdr_valid),
    .s_udp_hdr_ready(udp_hdr_ready),
    .s_udp_ip_source_ip(udp_ip_dest_ip), 
    .s_udp_ip_dest_ip(udp_ip_source_ip), 
    .s_udp_source_port(udp_dest_port),  
    .s_udp_dest_port(udp_source_port), 
    .s_udp_length(udp_length),
    .s_udp_checksum(16'd0),            
    .s_udp_ip_dscp(6'd0),
    .s_udp_ip_ecn(2'd0),
    .s_udp_ip_ttl(8'd64),
    
    .s_udp_payload_axis_tdata(udp_tx_stream.tdata),
    .s_udp_payload_axis_tvalid(udp_tx_stream.tvalid),
    .s_udp_payload_axis_tready(udp_tx_stream.tready),
    .s_udp_payload_axis_tlast(udp_tx_stream.tlast),
    .s_udp_payload_axis_tuser(udp_tx_stream.tuser),

    // Config
    .local_mac(48'h02_00_00_00_00_00),
    .local_ip({8'd192, 8'd168, 8'd1, 8'd128}), // The FPGA's IP: 192.168.1.128
    .gateway_ip({8'd192, 8'd168, 8'd1, 8'd1}),
    .subnet_mask({8'd255, 8'd255, 8'd255, 8'd0}),
    .clear_arp_cache(1'b0)
);


endmodule : ethernet_core
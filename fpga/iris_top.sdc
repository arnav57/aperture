# ---------------------------------------------------------------------------
# Timing constraints for aperture: AI Enabled Wi-Fi Based Imaging
# Target: Terasic DE2-115 (EP4CE115F29C7)
# ---------------------------------------------------------------------------
# Modeled on the verilog-ethernet DE2-115 example design.
#
# Clock structure:
#   refclk_i [50 MHz] -> I_pll_0 (ALTPLL)
#     clk0 -> eth_clk_main  [125 MHz,  0 deg] (RGMII gtx_clk)
#     clk1 -> eth_clk_shift [125 MHz, 90 deg] (RGMII gtx_clk90)
#     clk2 -> dp_clk        [150 MHz,  0 deg] (compute domain)
# ENET1 RX clock (ENET1_RX_CLK) is an asynchronous input clock from the PHY.
# ---------------------------------------------------------------------------

# Board clock: 50 MHz oscillator on CLOCK_50 (PIN_Y2)
create_clock -period 20.000 -name {refclk_i} [get_ports {refclk_i}]

# Asynchronous board reset input
set_false_path -from [get_ports {rstn_i}] -to *

# Static status output (LED)
set_false_path -from * -to [get_ports {pll_lock_o}]

# Reset / control synchronizer false paths (std_rstn_sync / std_clk_ctrl)
set_false_path -to [get_registers -nowarn *I_rstn_sync_clk_ctrl|I_rst_sync|flop_r*]
set_false_path -to [get_registers -nowarn *I_data_sync_clk_en_s3r|flop_r*]

# ---------------------------------------------------------------------------
# verilog-ethernet / verilog-axis constraint procedures
# ---------------------------------------------------------------------------
source ../asic/external/verilog-ethernet/syn/quartus/eth_mac_1g_rgmii.sdc
source ../asic/external/verilog-ethernet/syn/quartus/rgmii_phy_if.sdc
source ../asic/external/verilog-ethernet/syn/quartus/rgmii_io.sdc
source ../asic/external/verilog-axis/syn/quartus/axis_async_fifo.sdc

# ---------------------------------------------------------------------------
# ENET1 RGMII MAC (eth_mac_1g_rgmii_fifo I_eth_mac_fifo)
# Constrains internal config syncs and the gtx_clk <-> compute_clk CDC FIFOs
# ---------------------------------------------------------------------------
constrain_eth_mac_1g_rgmii_inst "I_enet_1|I_eth_core|I_eth_mac|I_eth_mac_fifo|eth_mac_1g_rgmii_inst"
constrain_axis_async_fifo_inst "I_enet_1|I_eth_core|I_eth_mac|I_eth_mac_fifo|tx_fifo|fifo_inst"
constrain_axis_async_fifo_inst "I_enet_1|I_eth_core|I_eth_mac|I_eth_mac_fifo|rx_fifo|fifo_inst"

# ---------------------------------------------------------------------------
# ENET1 RGMII board interface
# RX: clocked by PHY-provided ENET1_RX_CLK (source-synchronous, DDR data)
# TX: launched by the PLL 125 MHz clock routed out on ENET1_GTX_CLK
# ---------------------------------------------------------------------------
constrain_rgmii_input_pins "enet1" "ENET1_RX_CLK" "ENET1_RX_DV ENET1_RX_DATA*"
constrain_rgmii_output_pins "enet1" "I_clkgen|I_pll_0|altpll_component|auto_generated|pll1|clk[0]" "ENET1_GTX_CLK" "ENET1_TX_EN ENET1_TX_DATA*"

derive_pll_clocks
derive_clock_uncertainty

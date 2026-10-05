`timescale 1ns/1ps
`default_nettype none


module iris_clkgen (

    // Inputs
    input wire refclk_i,    // 50 MHz crystal osc
    input wire rstn_i,      // Main async active low reset

    // Generated Clocks (free running)
    output wire eth_clk_main_o,
    output wire eth_clk_shift_o,
    output wire dp_clk_o,

    // Synchronized Resets (async assert)
    output wire rstn_eth_clk_o,
    output wire rstn_dp_clk_o,

    // Status Flags
    output wire pll_lock_o
);  

    logic eth_clk_main_fr;;
    logic eth_clk_shift_fr;
    logic dp_clk_fr;

    ///// Altera PLL Instantiation
    /*/
    ///                     |--------| -----> eth_clk_main  [125 MHz, 00 deg]
    /// Refclk [50 MHz] --> |  PLL0  | -----> eth_clk_shift [125 MHz, 90 deg]
    ///                     |--------| -----> dp_clk        [150 MHz, 00 deg]
    /*/
    iris_pll I_pll_0 (
        .areset ( ~rstn_i          ),
        .inclk0 ( refclk_i         ),
        .c0     ( eth_clk_main_fr  ),
        .c1     ( eth_clk_shift_fr ),
        .c2     ( dp_clk_fr        ),
        .locked ( pll_lock_o       )
    );

    ///////// Clock Control Blocks

    logic rstn_int; // hold all domains in reset until PLL is locked
    assign rstn_int = (rstn_i & pll_lock_o);

    std_clk_ctrl I_clk_ctrl_eth_clk_main (
        .clk_i      ( eth_clk_main_fr ),
        .rstn_i     ( rstn_int        ),
        .clk_en_i   ( 1'b1            ),
        .clk_div_i  ( 4'b1            ),
        .clk_o      ( eth_clk_main_o  ),
        .rstn_o     ( rstn_eth_clk_o  ),
        .clk_fr_o   ( /* FLOATING  */ )
    );

    std_clk_ctrl I_clk_ctrl_eth_clk_shift (
        .clk_i      ( eth_clk_shift_fr ),
        .rstn_i     ( rstn_int         ),
        .clk_en_i   ( 1'b1             ),
        .clk_div_i  ( 4'b1             ),
        .clk_o      ( eth_clk_shift_o  ),
        .rstn_o     (  /* FLOATING  */ ),
        .clk_fr_o   (  /* FLOATING  */ )
    );

    std_clk_ctrl I_clk_ctrl_dp_clk (
        .clk_i      ( dp_clk_fr        ),
        .rstn_i     ( rstn_int         ),
        .clk_en_i   ( 1'b1             ),
        .clk_div_i  ( 4'b1             ),
        .clk_o      ( dp_clk_o         ),
        .rstn_o     ( rstn_dp_clk_o    ),
        .clk_fr_o   (  /* FLOATING  */ )
    );


endmodule : iris_clkgen

`default_nettype wire
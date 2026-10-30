/// Schmidl-Cox style autocorrelator

`timescale 1ns/1ps
`default_nettype none

module stf_cfo_top (
    input wire clk_i,
    input wire rstn_i,

    // Aligned IQ Stream
    input wire signed [7:0] I_i,
    input wire signed [7:0] Q_i,
    input wire signed       valid_i
);

///////////////////////////////////////////////////////
/// This blocks job is to detect the OFDM packets STF,
/// And provide a measure of CFO correction.
///
/// This algorithm requires three things to work
///    1. Autocorrelator with lag of 16
///    2. Current Signal Energy
///    3. A Decision Metric based on (1) and (2)
///////////////////////////////////////////////////////
    
endmodule : stf_cfo_top
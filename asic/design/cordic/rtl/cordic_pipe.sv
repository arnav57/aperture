// N stage pipelined CORDIC implementation.
// assumes input is in: [-90 to 90] deg range

`timescale 1ns/1ps
`default_nettype none

module cordic_pipe #(
    parameter int NUM_STAGES      = 14,  // How many stages is this CORDIC?
    parameter int BAR_ANGLE_WIDTH = 16, // Width of the BAR table input
    parameter int VECTOR_WIDTH    = 18  // 16 bits data + 2 gain bits for CORDIC gain (~1.64)
)(
    input wire clk_i,
    input wire rstn_i,

    // inputs to CORDIC algorithm (Q3.15)
    input wire signed [VECTOR_WIDTH-1:0]    x_i,
    input wire signed [VECTOR_WIDTH-1:0]    y_i,
    // input angle BAR-16
    input wire signed [BAR_ANGLE_WIDTH-1:0] z_i,
    input wire                              en_i,
    input wire                     [3-1:0]  fold_i,

    // outputs from last CORDIC (Q3.15)
    output wire signed [VECTOR_WIDTH-1:0]    x_o,
    output wire signed [VECTOR_WIDTH-1:0]    y_o,
    // output angle BAR-16
    output wire signed [BAR_ANGLE_WIDTH-1:0] z_o,
    output wire                              valid_o,
    output wire                      [3-1:0] fold_o
);

// abutments
logic signed [NUM_STAGES:0][VECTOR_WIDTH-1:0]    x_mesh;
logic signed [NUM_STAGES:0][VECTOR_WIDTH-1:0]    y_mesh;
logic signed [NUM_STAGES:0][BAR_ANGLE_WIDTH-1:0] z_mesh;
logic signed [NUM_STAGES:0]                      vld_mesh;
logic signed [NUM_STAGES:0][3-1:0]               fold_mesh;

// theta values (notice the 0:13 and not 13:0 here)
localparam logic signed [15:0] theta_values [0:13] = '{
    16'sd8192,  // atan(2^-0)  = 45.000000°
    16'sd4836,  // atan(2^-1)  = 26.565051°
    16'sd2555,  // atan(2^-2)  = 14.036243°
    16'sd1297,  // atan(2^-3)  =  7.125016°
    16'sd651,   // atan(2^-4)  =  3.576334°
    16'sd326,   // atan(2^-5)  =  1.789911°
    16'sd163,   // atan(2^-6)  =  0.895174°
    16'sd81,    // atan(2^-7)  =  0.447614°
    16'sd41,    // atan(2^-8)  =  0.223811°
    16'sd20,    // atan(2^-9)  =  0.111906°
    16'sd10,    // atan(2^-10) =  0.055953°
    16'sd5,     // atan(2^-11) =  0.027976°
    16'sd3,     // atan(2^-12) =  0.013988°
    16'sd1      // atan(2^-13) =  0.006994°
};

// instantiate the chain of CORDIC stages
genvar i;
generate for (i = 0; i < NUM_STAGES ; i++ ) begin : gen_cordic_pipe
    cordic_stage #(
        .STAGE_INDEX     (i              ),
        .BAR_ANGLE_WIDTH (BAR_ANGLE_WIDTH),
        .VECTOR_WIDTH    (VECTOR_WIDTH   )
    ) I_cordic_stage (
        // required
        .clk_i (clk_i),
        .rstn_i (rstn_i),
        .theta_i ( theta_values[i] ),
        // inputs
        .x_i ( x_mesh[i] ),
        .y_i ( y_mesh[i] ),
        .z_i ( z_mesh[i] ),
        .en_i( vld_mesh[i]),
        .fold_i( fold_mesh[i] ),
        // outputs
        .x_o ( x_mesh[i+1] ),
        .y_o ( y_mesh[i+1] ),
        .z_o ( z_mesh[i+1] ),
        .valid_o( vld_mesh[i+1]),
        .fold_o(fold_mesh[i+1])
    );
end
endgenerate

assign x_mesh[0] = x_i;
assign y_mesh[0] = y_i;
assign z_mesh[0] = z_i;
assign vld_mesh[0] = en_i;
assign fold_mesh[0] = fold_i;

assign x_o = x_mesh[NUM_STAGES];
assign y_o = y_mesh[NUM_STAGES];
assign z_o = z_mesh[NUM_STAGES];
assign valid_o = vld_mesh[NUM_STAGES];
assign fold_o = fold_mesh[NUM_STAGES];

endmodule : cordic_pipe

`default_nettype wire
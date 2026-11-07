// CORDIC Implementation for sin(x) and cos(x).
// Supports Angle folding for [-180, 180] range of inputs
// Basic Angle Folding logic contains two things, due to CORDIC only operating within the +90 to -90 deg range
//  1. Decide what to fold on (+90 or -90)
//      - z_i in [-180 , -90) -> fold by +90
//      - z_i in (-90, +90)   -> fold by 0
//      - z_i in (+90, +180)  -> fold by -90
//     This schema makes any angle in -180 to +180 become an equivalent angle within CORDIC's supported range
//
//  2. What is the transformation on the vectors?
//      - Based on angle folding we can derive this via the rotation matrix by doing the opposite rotation
//      - fold by +90 :: (x,y) -> (y, -x)
//      - fold by -90 :: (x,y) -> (-y, x)
//
// This Block also supports STATIC setting of Rotation Mode or Vectoring Mode!
//      input wire vmode_i --> 0 = rotation mode, 1 = vectoring mode

`timescale 1ns/1ps
`default_nettype none

module cordic #(
    parameter int NUM_STAGES      = 14,  // How many stages is this CORDIC?
    parameter int BAR_ANGLE_WIDTH = 16, // Width of the BAR table input
    parameter int VECTOR_WIDTH    = 18  // 16 bits data + 2 gain bits for CORDIC gain (~1.64)
)(
    input wire clk_i,
    input wire rstn_i,
    input wire vmode_i, // 0 = rotation mode CORDIC, 1 = vectoring mode cordic, assumed static during usage

    // input angle BAR-16
    input wire signed [BAR_ANGLE_WIDTH-1:0] z_i,
    input wire                              en_i,
    input wire signed [VECTOR_WIDTH-1:0]    x_i,
    input wire signed [VECTOR_WIDTH-1:0]    y_i,

    // outputs from last CORDIC (Q3.15)
    output wire signed [VECTOR_WIDTH-1:0]    x_o,
    output wire signed [VECTOR_WIDTH-1:0]    y_o,
    // output angle BAR-16
    output wire signed [BAR_ANGLE_WIDTH-1:0] z_o,
    output wire                              valid_o
);

// cordic_fold --> input MUX (for rotation mode)
logic signed [BAR_ANGLE_WIDTH-1:0] z_folded;
logic                      [3-1:0] fold_type_in;

// cordic_preflow -> input MUX (for vectoring mode)
logic signed [VECTOR_WIDTH-1:0]    x_pre;
logic signed [VECTOR_WIDTH-1:0]    y_pre;
logic signed [BAR_ANGLE_WIDTH-1:0] z_pre;

// input MUX -> cordic_pipe
logic signed [VECTOR_WIDTH-1:0]    x_pipe;
logic signed [VECTOR_WIDTH-1:0]    y_pipe;
logic signed [BAR_ANGLE_WIDTH-1:0] z_pipe;
logic        [3-1:0]               fold_pipe;

// cordic_pipe -> cordic_transform
logic signed [VECTOR_WIDTH-1:0]    x_no_transform; // Q3.15
logic signed [VECTOR_WIDTH-1:0]    y_no_transform; // Q3.15
logic                      [3-1:0] fold_type_out;


// Rotation Mode
// First determine what fold we need, apply the angle folding
// and pass the fold decision thru the pipeline
    cordic_fold #(
        .BAR_ANGLE_WIDTH ( BAR_ANGLE_WIDTH )
    ) I_cordic_fold (
        .z_i ( z_i ),
        .z_o ( z_folded ),
        .fold_o (fold_type_in )
    );

// Vector Mode We bring the vector into the RHP. Initializing Z = 0 or 180 deg.
    cordic_prefold #(
    	.BAR_ANGLE_WIDTH( BAR_ANGLE_WIDTH ),
    	.VECTOR_WIDTH   ( VECTOR_WIDTH )
     ) I_cordic_prefold (
    	.x_i(x_i),
    	.y_i(y_i),
    	.x_o(x_pre),
    	.y_o(y_pre),
    	.z_o(z_pre)
    );

// Mode Select MUX
    localparam logic signed [3-1:0] NO_FOLD = 3'b001;
    assign x_pipe    = vmode_i ? x_pre : x_i;
    assign y_pipe    = vmode_i ? y_pre : y_i;
    assign z_pipe    = vmode_i ? z_pre : z_folded;
    assign fold_pipe = vmode_i ? NO_FOLD : fold_type_in;

// CORDIC Algorithm Stages
    cordic_pipe #(
        .NUM_STAGES ( NUM_STAGES ),
        .BAR_ANGLE_WIDTH ( BAR_ANGLE_WIDTH ),
        .VECTOR_WIDTH ( VECTOR_WIDTH )
    ) I_cordic_pipe (
        .clk_i ( clk_i ),
        .rstn_i ( rstn_i ),
        .vmode_i ( vmode_i ),
        // inputs
        .en_i ( en_i ),
        .x_i ( x_pipe),
        .y_i ( y_pipe ),
        .z_i ( z_pipe ),
        .fold_i ( fold_pipe ),
        // outputs
        .x_o ( x_no_transform ),
        .y_o ( y_no_transform ),
        .z_o ( z_o ),
        .valid_o ( valid_o ),
        .fold_o ( fold_type_out )
    );

// Angle Transformation back to original (passthru in vectoring mode)
    cordic_transform #(
        .VECTOR_WIDTH ( VECTOR_WIDTH )
    ) I_cordic_transform (
        .fold_i ( fold_type_out ),
        .x_i ( x_no_transform ),
        .y_i ( y_no_transform ),
        .x_o ( x_o ),
        .y_o ( y_o )
    );



endmodule : cordic

`default_nettype wire

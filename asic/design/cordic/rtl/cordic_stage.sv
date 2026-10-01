// Single Pipelined CORDIC Stage [-90 to 90] deg

`timescale 1ns/1ps
`default_nettype none

module cordic_stage #(
    parameter int STAGE_INDEX     = 1,  // What stage in the pipeline is this current unit?
    parameter int BAR_ANGLE_WIDTH = 16, // Width of the BAR table input
    parameter int VECTOR_WIDTH    = 18  // 16 bits data + 2 gain bits for CORDIC gain (~1.64)
) (
    input wire clk_i,
    input wire rstn_i,

    // per stage inputs
    input wire signed [BAR_ANGLE_WIDTH-1:0] theta_i, // angle step size for this stage (BAR)

    // cordic algorithm state (in)
    input wire signed [VECTOR_WIDTH-1:0]    x_i, // current value of x-vector
    input wire signed [VECTOR_WIDTH-1:0]    y_i, // current value of y-vector
    input wire signed [BAR_ANGLE_WIDTH-1:0] z_i, // current angle "error" (BAR)
    input wire                              en_i,

    // metadata for angle folding
    input wire        [3-1:0]               fold_i,
    output wire       [3-1:0]               fold_o,

    // to next cordic_stage
    output wire signed [VECTOR_WIDTH-1:0]    x_o, // current value of x-vector
    output wire signed [VECTOR_WIDTH-1:0]    y_o, // current value of y-vector
    output wire signed [BAR_ANGLE_WIDTH-1:0] z_o,  // current angle "error" (BAR)
    output wire                              valid_o
);

logic signed [VECTOR_WIDTH-1:0]    x_r;
logic signed [VECTOR_WIDTH-1:0]    y_r;
logic signed [BAR_ANGLE_WIDTH-1:0] z_r;

// direction is comb
logic                       step_down;
assign step_down = (z_i[BAR_ANGLE_WIDTH-1]); // direction of step = sign(angle_i) which can be found with MSb of z_i

// reuse the shifters
logic signed [VECTOR_WIDTH-1:0] y_asr;
logic signed [VECTOR_WIDTH-1:0] x_asr;
assign y_asr = (y_i >>> STAGE_INDEX);
assign x_asr = (x_i >>> STAGE_INDEX);


always_ff @(posedge clk_i, negedge rstn_i) begin
    if (~rstn_i) begin
        x_r <= '0;
        y_r <= '0;
        z_r <= '0;
    end else begin
        if (en_i) begin
            if (step_down) begin
                // if we rotate CCW (-ve)
                x_r <= x_i + y_asr;
                y_r <= y_i - x_asr;
                z_r <= z_i + theta_i;
            end else begin
                // if we rotate CW (+ve)
                x_r <= x_i - y_asr;
                y_r <= y_i + x_asr;
                z_r <= z_i - theta_i;
            end
        end
    end
end

// drive valid as a 1UI delay on en
// also flop the fold decision and propagate it
logic valid_r;
logic [2:0] fold_r;
always_ff @(posedge clk_i, negedge rstn_i) begin
    if (~rstn_i) begin
        valid_r <= 1'b0;
        fold_r  <= 3'b0;
    end else begin
        valid_r <= en_i;
        fold_r  <= fold_i;
    end
end

assign x_o = x_r;
assign y_o = y_r;
assign z_o = z_r;
assign valid_o = valid_r;
assign fold_o  = fold_r;

endmodule : cordic_stage

`default_nettype wire
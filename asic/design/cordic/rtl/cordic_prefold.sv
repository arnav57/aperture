`timescale 1ns/1ps
`default_nettype none

// Module to apply proper folding during vectoring mode.

module cordic_prefold #(
    parameter int BAR_ANGLE_WIDTH = 16,
    parameter int VECTOR_WIDTH    = 18
) (
    input wire signed [VECTOR_WIDTH-1:0] x_i,
    input wire signed [VECTOR_WIDTH-1:0] y_i,

    // to cordic_pipe, always >= 0
    output logic signed [VECTOR_WIDTH-1:0]   x_o,
    output logic signed [VECTOR_WIDTH-1:0]   y_o,
    output logic signed [BAR_ANGLE_WIDTH-1:0] z_o

);

    localparam logic signed [BAR_ANGLE_WIDTH-1:0] HALF_TURN = {1'b1, {(BAR_ANGLE_WIDTH-1){1'b0}} };

    always_comb begin
        if (x_i[VECTOR_WIDTH-1]) begin
            // x < 0 -> rotate by +180
            x_o = -x_i;
            y_o = -y_i;
            z_o = HALF_TURN;
        end else begin
            // x >= 0 -> passthru
            x_o = x_i;
            y_o = y_i;
            z_o = 'b0;
        end
    end

endmodule : cordic_prefold

`default_nettype wire

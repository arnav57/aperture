// 90 degree angle folder for a 16bit BAR CORDIC unit
// does not apply transformation at the output

`timescale 1ns/1ps
`default_nettype none

module cordic_fold #(
    parameter int BAR_ANGLE_WIDTH = 16
) (
    // input angle BAR-16, will be fed into CORDIC PIPE
    input wire signed  [BAR_ANGLE_WIDTH-1:0]  z_i,      // BAR-16 (from user)
    output wire signed [BAR_ANGLE_WIDTH-1:0]  z_o,      // BAR-16 (to CORDIC pipe)
    output wire        [3-1:0]                fold_o    // tracked fold decision
);

// for readability
localparam int MAX_NUM      = 2 ** BAR_ANGLE_WIDTH;
localparam int PLUS_180_DEG = MAX_NUM >> 1;
localparam int PLUS_90_DEG  = PLUS_180_DEG >> 1;
localparam int NEG_180_DEG  = -PLUS_180_DEG;
localparam int NEG_90_DEG   = -PLUS_90_DEG;

// Angle Folding Decision
    typedef enum logic [2:0] { 
        NONE         = 3'b001,
        FOLD_PLUS_90 = 3'b010,
        FOLD_NEG_90  = 3'b100
    } e_fold_type;

    e_fold_type fold_type;
    logic signed [BAR_ANGLE_WIDTH-1:0] z_folded;

    always_comb begin
        if (PLUS_180_DEG >= z_i && z_i > PLUS_90_DEG ) begin
            fold_type = FOLD_NEG_90;
            z_folded    = z_i + NEG_90_DEG;
        end else if (NEG_90_DEG > z_i && z_i >= NEG_180_DEG ) begin
            fold_type = FOLD_PLUS_90;
            z_folded    = z_i + PLUS_90_DEG;
        end else begin
            fold_type = NONE;
            z_folded    = z_i;
        end
    end

// MLIO Assignments
assign z_o    = z_folded;
assign fold_o = fold_type;

endmodule : cordic_fold
`timescale 1ns/1ps
`default_nettype none

module cordic_transform #(
    parameter int VECTOR_WIDTH = 18
) (
    input wire signed [VECTOR_WIDTH-1:0] x_i,
    input wire signed [VECTOR_WIDTH-1:0] y_i,
    input wire                   [3-1:0] fold_i,

    output logic signed [VECTOR_WIDTH-1:0] x_o,
    output logic signed [VECTOR_WIDTH-1:0] y_o
);

    typedef enum logic [2:0] { 
        NONE         = 3'b001,
        FOLD_PLUS_90 = 3'b010,
        FOLD_NEG_90  = 3'b100
    } e_fold_type;

    e_fold_type fold_type;
    assign fold_type = e_fold_type'(fold_i);

    logic signed [VECTOR_WIDTH-1:0] x_neg;
    logic signed [VECTOR_WIDTH-1:0] y_neg;
    assign x_neg = ~x_i + VECTOR_WIDTH'(1);
    assign y_neg = ~y_i + VECTOR_WIDTH'(1);


    always_comb begin
        case (fold_type)
            NONE: begin
                // (x,y) -> (x,y)
                x_o = x_i;
                y_o = y_i;
            end

            FOLD_PLUS_90: begin
                // rotate -90 deg to undo fold
                // (x,y) -> (y, -x)
                x_o = y_i;
                y_o = x_neg;
            end

            FOLD_NEG_90: begin
                // rotate +90 deg to undo fold
                // (x,y) -> (-y, x)
                x_o = y_neg;
                y_o = x_i;
            end

            default:  begin
                // (x,y) -> (x,y)
                x_o = x_i;
                y_o = y_i;
            end
        endcase
    end

endmodule : cordic_transform

`default_nettype wire
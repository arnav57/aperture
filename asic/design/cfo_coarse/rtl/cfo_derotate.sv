`timescale 1ns/1ps
`default_nettype none

/*
// This module basically undoes the CFO phase drift by using an estimate of the CFO angle.
// the phase rotator steps by -1 * cfo_angle_i / 16.
*/

module cfo_derotate (
    input wire clk_i,
    input wire rstn_i,

    input wire signed [15:0] I_i,
    input wire signed [15:0] Q_i,
    input wire               IQ_valid_i,

    input wire signed [15:0] cfo_angle_i,
    input wire               cfo_valid_i,

    // derotated samples
    output logic signed [15:0] I_o,
    output logic signed [15:0] Q_o,
    output logic               IQ_valid_o
);

    localparam int PHASE_FRAC_BITS = 4;
    localparam int PHASE_WIDTH     = 16 + PHASE_FRAC_BITS;
    localparam int VECTOR_WIDTH    = 16 + 3 + 2;

/// Phase Accumulator
    logic signed [PHASE_WIDTH-1:0] phase_step_r;
    logic signed [PHASE_WIDTH-1:0] phase_r;

    logic signed [PHASE_WIDTH-1:0] cfo_angle_cast;
    logic signed [PHASE_WIDTH-1:0] cfo_angle_neg;
    assign cfo_angle_cast = PHASE_WIDTH'(cfo_angle_i);
    assign cfo_angle_neg  = -cfo_angle_cast;

    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            phase_r      <= 'd0;
            phase_step_r <= 'd0;
        end else begin
            if (cfo_valid_i) begin
                phase_step_r <= cfo_angle_neg;
            end else if (IQ_valid_i) begin
                phase_r <= phase_r +  phase_step_r;
            end
        end
    end

/// Derotate the samples with a rotation mode CORDIC
    logic signed [VECTOR_WIDTH-1:0] I_ext, Q_ext;
    assign I_ext = VECTOR_WIDTH'(I_i) <<< PHASE_FRAC_BITS;
    assign Q_ext = VECTOR_WIDTH'(Q_i) <<< PHASE_FRAC_BITS;

    logic signed [VECTOR_WIDTH-1:0] I_cordic, Q_cordic;
    logic                           IQ_cordic_valid;

    cordic #(
    	.NUM_STAGES     ( 14 ),
    	.BAR_ANGLE_WIDTH( 16 ),
    	.VECTOR_WIDTH   ( VECTOR_WIDTH )
     ) cordic (
    	.clk_i  ( clk_i  ),
    	.rstn_i ( rstn_i ),
    	.vmode_i(  1'b0  ), // need rotation mode here
    	.z_i    ( phase_r[PHASE_WIDTH-1 -: 16] ), // take top 16 bits of the phase accumulator
    	.en_i   ( IQ_valid_i ),
    	.x_i    ( I_ext ),
    	.y_i    ( Q_ext ),
    	.x_o    ( I_cordic ),
    	.y_o    ( Q_cordic ),
    	.valid_o( IQ_cordic_valid ),
    	.z_o    (  ) // unused
    );

/// CORDIC Gain compenstation. CORDIC gain is a fixed amount, we can remove it here
    localparam int CORDIC_GAIN  = 39797; // =  round(65536 / 1.646), 1.646 is trhe cordic gain
    localparam int NUM_SHIFT    = PHASE_FRAC_BITS + 16;
    localparam int MUL_WIDTH    = VECTOR_WIDTH + 18;

    logic signed [MUL_WIDTH-1:0] gain, round, I_mul, Q_mul;
    assign gain  = MUL_WIDTH'(CORDIC_GAIN);
    assign round = MUL_WIDTH'(1) <<< (NUM_SHIFT + 1);
    assign I_mul = MUL_WIDTH'(I_cordic) * gain + round;
    assign Q_mul = MUL_WIDTH'(Q_cordic) * gain + round;

    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            I_o        <= 'd0;
            Q_o        <= 'd0;
            IQ_valid_o <= 1'd0;
        end else begin
            I_o        <= I_mul >>> NUM_SHIFT;
            Q_o        <= Q_mul >>> NUM_SHIFT;
            IQ_valid_o <= IQ_cordic_valid;
        end
    end

endmodule : cfo_derotate

`default_nettype wire

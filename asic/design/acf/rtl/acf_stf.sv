`timescale 1ns/1ps
`default_nettype none

module acf_stf #(
    parameter int IQ_WIDTH = 8
) (
    input wire clk_i,
    input wire rstn_i,

    // X(t) = I + jQ
    input wire signed [IQ_WIDTH-1:0] I_i,
    input wire signed [IQ_WIDTH-1:0] Q_i,

    output wire signed [2*IQ_WIDTH+4:0] P_real_o,
    output wire signed [2*IQ_WIDTH+4:0] P_imag_o
);

///// localparams
    localparam int LAGS             = 16;
    localparam int NUM_DELAY_STAGES = 2 * LAGS;


///// delay line
    logic signed [NUM_DELAY_STAGES-1:0][IQ_WIDTH-1:0] i_dly;
    logic signed [NUM_DELAY_STAGES-1:0][IQ_WIDTH-1:0] q_dly;

    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            i_dly <= '0;
            q_dly <= '0;
        end else begin
            i_dly[0] <= I_i;
            q_dly[0] <= Q_i;
            for (int i = 0; i < NUM_DELAY_STAGES - 1 ; i++ ) begin
                i_dly[i+1] <= i_dly[i];
                q_dly[i+1] <= q_dly[i]; 
            end
        end
    end

///// Complex Multiplications
    logic signed [2*IQ_WIDTH:0] onelag_real;
    logic signed [2*IQ_WIDTH:0] onelag_imag;
    logic signed [2*IQ_WIDTH:0] twolag_real;
    logic signed [2*IQ_WIDTH:0] twolag_imag;

    logic signed [2*IQ_WIDTH+4:0] p_real;   // 16 terms are gonna be added here, need extra 5 bits after the mul
    logic signed [2*IQ_WIDTH+4:0] p_imag;   // 16 terms are gonna be added here, need extra 5 bits after the mul

// K1 = x[t+L] * conj(x[t+2L])
    cmp_mul #(
        .INPUT_WIDTH ( IQ_WIDTH )
    ) I_cmul_2L (
        .a_i ( i_dly[LAGS-1] ),
        .b_i ( q_dly[LAGS-1] ),
        .c_i ( I_i  ),
        .d_i ( -Q_i ), // sv should infer a twos-comp inversion here
        .x_o ( twolag_real ),
        .y_o ( twolag_imag )
    );

// K2 = x[t] * conj(x[t+L])
    cmp_mul #(
        .INPUT_WIDTH ( IQ_WIDTH )
    ) I_cmul_1L (
        .a_i ( i_dly[NUM_DELAY_STAGES-1] ),
        .b_i ( q_dly[NUM_DELAY_STAGES-1] ),
        .c_i ( i_dly[LAGS-1] ),
        .d_i ( -q_dly[LAGS-1] ), // sv should infer a twos-comp inversion here
        .x_o ( onelag_real ),
        .y_o ( onelag_imag )
    );

// P[t+1] = P[t] + K1 - K2
    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            p_real <= '0;
            p_imag <= '0;
        end else begin
            p_real <= p_real + twolag_real - onelag_real;
            p_imag <= p_imag + twolag_imag - onelag_imag;
        end
    end


///// MLIO
    assign P_real_o  = p_real;
    assign P_imag_o  = p_imag;

endmodule : acf_stf

`default_nettype wire




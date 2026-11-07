`timescale 1ns/1ps
`default_nettype none

module stf_acf (
    input wire clk_i,
    input wire rstn_i,

    input wire signed [15:0] I_i,
    input wire signed [15:0] Q_i,
    input wire               IQ_valid_i,

    output wire signed [35:0] acf_re_o,
    output wire signed [35:0] acf_im_o,
    output wire               acf_valid_o,

    // ALso export some taps from the delay line for use in the energy calculation
    output wire signed [15:0] I_d16_o,
    output wire signed [15:0] Q_d16_o
);

/// need 32 cc delay line for sliding window of 16.
    localparam int NUM_LAGS = 32;
    logic signed [NUM_LAGS-1:0][15:0] I_dNr;
    logic signed [NUM_LAGS-1:0][15:0] Q_dNr;

    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            I_dNr <= 'd0;
            Q_dNr <= 'd0;
        end else begin
            if (IQ_valid_i) begin
                I_dNr[0] <= I_i;
                Q_dNr[0] <= Q_i;
                for (int i = 1 ; i < NUM_LAGS ; i++) begin
                    I_dNr[i] <= I_dNr[i-1];
                    Q_dNr[i] <= Q_dNr[i-1];
                end
            end
        end
    end

/// Autocorrelation Function Implmentation
    logic signed [15:0] x_re;
    logic signed [15:0] x_im;
    assign x_re = I_i;
    assign x_im = Q_i;

    logic signed [15:0] x_d16_re;
    logic signed [15:0] x_d16_im;
    assign x_d16_re = I_dNr[15];
    assign x_d16_im = Q_dNr[15];
    assign I_d16_o  = I_dNr[15];
    assign Q_d16_o  = Q_dNr[15];

    logic signed [15:0] x_d32_re;
    logic signed [15:0] x_d32_im;
    assign x_d32_re = I_dNr[31];
    assign x_d32_im = Q_dNr[31];

    localparam int MUL_WIDTH = 2 * 16 + 1;
    logic signed [MUL_WIDTH-1:0] new_term_re;
    logic signed [MUL_WIDTH-1:0] new_term_im;
    logic signed [MUL_WIDTH-1:0] old_term_re;
    logic signed [MUL_WIDTH-1:0] old_term_im;

    // new_term = x[n] * conj(x[n-16])
    cmp_mul #(
        .CONJ_CD( 1'b1 )
    ) I_cmul_new_term (
        .clk_i ( clk_i ),
        .rstn_i ( rstn_i ),
        .a_i  ( x_re ),
        .b_i  ( x_im ),
        .c_i  ( x_d16_re ),
        .d_i  ( x_d16_im ),
        .x_o ( new_term_re ),
        .y_o ( new_term_im )
    );

    // old_term = x[n-16] * conj(x[n-32])
    cmp_mul #(
        .CONJ_CD ( 1'b1 )
    ) I_cmul_old_term (
        .clk_i ( clk_i ),
        .rstn_i ( rstn_i ),
        .a_i  ( x_d16_re ),
        .b_i  ( x_d16_im ),
        .c_i  ( x_d32_re ),
        .d_i  ( x_d32_im ),
        .x_o ( old_term_re ),
        .y_o ( old_term_im )
    );

// here we have 16 additions, this means we need log2(16) = 4 extra bits to store everything
localparam ACC_WIDTH = MUL_WIDTH + 4;
logic signed [ACC_WIDTH-1:0] acf_re;
logic signed [ACC_WIDTH-1:0] acf_im;

// We also gate the accumulator with a matched delay of the valid signal.
logic [2:0] valid_dNr;
always_ff @(posedge clk_i, negedge rstn_i) begin
    if (~rstn_i) begin
        valid_dNr <= 3'd0;
    end else begin
        valid_dNr <= {valid_dNr[1:0], IQ_valid_i}; // this is a shift register
    end
end

always_ff @(posedge clk_i, negedge rstn_i) begin
    if (~rstn_i) begin
        acf_re <= 'd0;
        acf_im <= 'd0;
    end else if (valid_dNr[2]) begin
        // only update the acf if the output of cmp_muls is valid
        acf_re <= acf_re + new_term_re - old_term_re;
        acf_im <= acf_im + new_term_im - old_term_im;
    end
end

assign acf_re_o = acf_re;
assign acf_im_o = acf_im;
assign acf_valid_o = valid_dNr[2];

endmodule : stf_acf

`default_nettype wire

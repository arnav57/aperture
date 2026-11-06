`timescale 1ns/1ps
`default_nettype none


module stf_energy (
    input wire clk_i,
    input wire rstn_i,

    // IQ values
    input wire signed [15:0] I_i,
    input wire signed [15:0] Q_i,
    input wire               IQ_valid_i,

    input wire signed [15:0] I_d16_i,
    input wire signed [15:0] Q_d16_i,

    // Energy Out
    output wire signed [35:0] E_o

);
    logic signed [32:0] new_term;
    cmp_abs_sq I_cabs_sq_new_term (
        .clk_i  ( clk_i    ),
        .rstn_i ( rstn_i   ),
        .X_i    ( I_i      ),
        .Y_i    ( Q_i      ),
        .Z_o    ( new_term )
    );

    logic signed [32:0] old_term;
    cmp_abs_sq I_cabs_sq_old_term (
        .clk_i  ( clk_i    ),
        .rstn_i ( rstn_i   ),
        .X_i    ( I_d16_i  ),
        .Y_i    ( Q_d16_i  ),
        .Z_o    ( old_term )
    );

    // need an extra cc to latency match the acf pipeline (which is 3 cc long for cmp_mul)
    logic signed [33:0] new_term_d1r;
    logic signed [33:0] old_term_d1r;
    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            new_term_d1r <= 34'b0;
            old_term_d1r <= 34'b0;
        end else begin
            new_term_d1r <= new_term;
            old_term_d1r <= old_term;
        end
    end

    logic [2:0] valid_dNr;
    logic [35:0] energy_r; // match the acf output width
    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            valid_dNr <= 3'b0;
            energy_r  <= 36'd0;
        end else begin
            valid_dNr <= {valid_dNr[1:0], IQ_valid_i};
            if (valid_dNr[2]) begin
                energy_r <= energy_r + new_term_d1r - old_term_d1r;
            end
        end
    end

    assign E_o = energy_r;

endmodule : stf_energy

`default_nettype wire

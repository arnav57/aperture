`timescale 1ns/1ps
`default_nettype none

module stf_decision (
    input wire clk_i,
    input wire rstn_i,

    // From stf_acf
    input wire signed [35:0] acf_re_i,
    input wire signed [35:0] acf_im_i,

    // From stf_energy
    input wire signed [35:0] energy_i,

    // Propose an STF Detection
    output wire stf_det_o
);

    localparam int SHIFTED_WIDTH  = 20;
    localparam int DECISION_WIDTH = 2 * SHIFTED_WIDTH + 1;

//// scale down acf/energy inputs by ASR 16 bits
    logic signed [SHIFTED_WIDTH-1:0] acf_raw_re_shift;
    logic signed [SHIFTED_WIDTH-1:0] acf_raw_im_shift;
    logic signed [SHIFTED_WIDTH-1:0] energy_shift;

    assign acf_raw_re_shift = (acf_re_i >>> 16);
    assign acf_raw_im_shift = (acf_im_i >>> 16);
    assign energy_shift     = (energy_i >>> 16);

//// calculate |acf|^2 = Re{acf}^2 + Im{acf}^2
    // this is 2 cc pipeline latency
    logic signed [DECISION_WIDTH-1:0] acf_abs_sq;
    cmp_abs_sq #(
        .INPUT_WIDTH ( SHIFTED_WIDTH )
    ) I_cabs_sq_acf_abs_sq (
        .clk_i  ( clk_i  ),
        .rstn_i ( rstn_i ),
        .X_i    ( acf_raw_re_shift ),
        .Y_i    ( acf_raw_im_shift ),
        .Z_o    ( acf_abs_sq )
    );

//// calculate the threshold = 0.75 * (Current Energy)
    // calculate threshold in 2 cc to latency match cmp_abs_sq
    logic signed [DECISION_WIDTH-1:0] energy_sq_r;
    logic signed [DECISION_WIDTH-1:0] threshold_r;
    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            energy_sq_r <= 'd0;
            threshold_r <= 'd0;
        end else begin
            energy_sq_r <= energy_shift * energy_shift;
            threshold_r <= (energy_sq_r - (energy_sq_r >>> 2));
        end
    end

//// EMA for tracking the Energy/Noise Floor
    logic signed [35:0] floor_r;
    logic signed [35:0] diff;
    // 10 for 20MSPs, might need to change this if f_s changes
    localparam int ALPHA = 10;

    assign diff = energy_i - floor_r;
    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            floor_r <= 36'd0;
        end else begin
            if (~stf_det_o) begin
                floor_r <= floor_r + (diff >>> ALPHA);
            end
        end
    end

//// Decision Metric (Propose if this block thinks the STF is here)
    logic stf_det_r, acf_above_threshold, above_energy_floor;
    assign acf_above_threshold = (acf_abs_sq > threshold_r);
    assign above_energy_floor = (energy_i > floor_r);

    logic [1:0] above_energy_floor_dNr; // this is latency matched by 2 cc as well.

    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            stf_det_r <= 1'd0;
            above_energy_floor_dNr <= 2'b0;
        end else begin
            stf_det_r <= acf_above_threshold & above_energy_floor_dNr[1];
            above_energy_floor_dNr <= {above_energy_floor_dNr[0], above_energy_floor};
        end
    end

    assign stf_det_o = stf_det_r;

endmodule : stf_decision

`default_nettype wire

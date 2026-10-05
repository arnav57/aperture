`timescale 1ns/1ps
`default_nettype none

module iris_byte_align (
    input wire          clk_i,
    input wire          rstn_i,

    input wire [7:0]    tdata_i,
    input wire          tvalid_i,
    input wire          tlast_i,

    output wire signed [7:0] I_o,
    output wire signed [7:0] Q_o,
    output wire              valid_o
);

/// Localparams
    localparam NUM_ALIGNED_BYTES = 2;
    localparam COUNTER_WIDTH = $clog2(NUM_ALIGNED_BYTES);

/// Modulo-N counter (N = NUM_ALIGNED_BYTES)
    logic [COUNTER_WIDTH-1:0] cnt_r;
    logic cnt_is_sat, cnt_is_sat_d1r;
    assign cnt_is_sat = (cnt_r == NUM_ALIGNED_BYTES - 1);

    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            cnt_r <= COUNTER_WIDTH'(0);
            cnt_is_sat_d1r <= 1'b0;
        end else begin
            cnt_is_sat_d1r <= cnt_is_sat;
            if (tlast_i & tvalid_i) begin
                // reset counter upon seeing tlast, this takes prio over regular counter operation
                // UDP dropping a byte means we permanently swap IQ for the rest of time
                // Which is why we reset the counter to 0 on tlast
                cnt_r <= COUNTER_WIDTH'(0);
            end else if (tvalid_i) begin
                cnt_r <= (cnt_is_sat) ? COUNTER_WIDTH'(0) : cnt_r + COUNTER_WIDTH'(1);
            end
        end
    end

/// Serial-In Parallel Out (Shift register)
    logic [NUM_ALIGNED_BYTES-1:0][7:0] shift_r;

    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            shift_r <= '0;
        end else begin
            if (tvalid_i) begin
                shift_r[0] <= tdata_i;
                shift_r[1] <= shift_r[0];
            end
        end
    end

    assign valid_o = cnt_is_sat_d1r;
    assign I_o     = shift_r[1];
    assign Q_o     = shift_r[0];

endmodule : iris_byte_align

`default_nettype wire
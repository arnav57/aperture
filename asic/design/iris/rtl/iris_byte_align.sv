/// Turns 4 Serial Bytes from Ethernet into a 2byte I and 2 byte Q value in parallel
/// Note: Here we have INT16 IQ encoding

`timescale 1ns/1ps
`default_nettype none

module iris_byte_align (
    input wire          clk_i,
    input wire          rstn_i,

    input wire [7:0]    tdata_i,
    input wire          tvalid_i,
    input wire          tlast_i,

    output wire signed [15:0] I_o,
    output wire signed [15:0] Q_o,
    output wire              valid_o
);

/// Localparams
    localparam NUM_ALIGNED_BYTES = 4;
    localparam COUNTER_WIDTH = $clog2(NUM_ALIGNED_BYTES);

/// Modulo-4 counter
    logic [COUNTER_WIDTH-1:0] cnt_r;
    logic currently_i, currently_q;
    logic cnt_is_max, cnt_is_max_d1r;

    // we are receveing I when the counter is 0 or 1, Q when its 2 or 3.
    assign currently_i = (cnt_r < 2'd2);
    assign currently_q = ~currently_i;
    assign cnt_is_max  = (cnt_r == 2'd3);

    always_ff @( posedge clk_i, negedge rstn_i ) begin
        if (~rstn_i) begin
            cnt_r <= COUNTER_WIDTH'(0);
            cnt_is_max_d1r <= 1'b0;
        end else begin
            cnt_is_max_d1r <= cnt_is_max & tvalid_i; 
            if (tlast_i && tvalid_i) begin
                // reset counter upon seeing tlast, this takes prio over regular counter operation
                // UDP dropping a byte means we permanently swap IQ for the rest of time
                // Which is why we reset the counter to 0 on tlast
                cnt_r <= COUNTER_WIDTH'(0);
            end else if (tvalid_i) begin
                cnt_r <= (cnt_is_max) ? COUNTER_WIDTH'(0) : cnt_r + COUNTER_WIDTH'(1);
            end  
        end
    end


/// SiPo (Serial In, Parallel Out) Shift Register
    logic signed [NUM_ALIGNED_BYTES-1:0][7:0] shift_r;

    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            shift_r <= '0;
        end else begin
            if (tvalid_i) begin
                shift_r[0] <= tdata_i;
                for (int i = 0 ; i < NUM_ALIGNED_BYTES - 1 ; i++ ) begin
                    shift_r[i+1] <= shift_r[i];
                end
            end
        end
    end 


/// MLIO
    assign valid_o = cnt_is_max_d1r;
    assign I_o     = {shift_r[3], shift_r[2]};
    assign Q_o     = {shift_r[1], shift_r[0]};


endmodule : iris_byte_align

`default_nettype wire
`timescale 1ns/1ps
`default_nettype none

/// CFO Coarse Estimation Block, works in tandem with stf_det to produce a CFO estimate
//  This CFO estimate is used in the LTF Cross-Correlator
//  In order to detect CFO from our stf-det (schmidl-cox style acf)
//      (1) --> Wait until stf_det_i rises
//      (2) --> Skip 8 acf samples as acf is still rising, the acf needs to be sampled AT the plateau
//      (3) --> Collect and Sum 64 acf samples as parallel Re{} and Im{} values
// This process above is implemented FSM style!

module cfo_coarse_est (
    input wire clk_i,
    input wire rstn_i,

    // From stf_det
    input wire               stf_det_i,
    input wire signed [35:0] acf_re_i,
    input wire signed [35:0] acf_im_i,
    input wire               acf_valid_i,

    // CFO Estimate (BAR16)
    output wire signed [15:0] cfo_angle_o,
    output wire               cfo_valid_o
);

/*
// Skip ~8 samples after posedge on stf_det_i
// This is needed because acf is probably still rising during assertion of stf_det_o.
// We need to sample stuff at the plateau to estimate CFO
*/


// Find a posedge on stf_det_i
    logic       stf_det_d1r, stf_det_rising;
    always_ff @(posedge clk_i, negedge rstn_i) begin
    	if (~rstn_i) begin
    	    stf_det_d1r <= 1'b0;
    	end else begin
    	    stf_det_d1r <= stf_det_i;
    	end
    end
    assign stf_det_rising = ~stf_det_d1r & stf_det_i;


// FSM
    localparam int NUM_ACF_SKIPS   = 8;
    localparam int NUM_ACF_SAMPLES = 64;
    localparam int NUM_ACF_HOLDS   = 32;
    localparam int MAX_COUNT   = (NUM_ACF_SAMPLES > NUM_ACF_SKIPS) ? NUM_ACF_SAMPLES : NUM_ACF_SKIPS;
    localparam int ACF_WIDTH   = 36;
    localparam int COUNT_WIDTH = $clog2(MAX_COUNT) + 1;
    localparam int SUM_WIDTH   = ACF_WIDTH + $clog2(NUM_ACF_SAMPLES);

    logic [COUNT_WIDTH-1:0]      acf_cnt_r;
    logic signed [SUM_WIDTH-1:0] acf_re_sum;
    logic signed [SUM_WIDTH-1:0] acf_im_sum;

    typedef enum logic [1:0] {
        IDLE,       // 2'd0
        ACF_SKIP,   // 2'd1
        ACF_SUM,    // 2'd2
        HOLD        // 2'd3
    } e_cfo_fsm_st;
    e_cfo_fsm_st fsm_st_r;
    logic done_r;

    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            fsm_st_r   <= IDLE;
            acf_cnt_r  <= COUNT_WIDTH'(0);
            done_r     <= 1'b0;
            acf_re_sum <= 'd0;
            acf_im_sum <= 'd0;
        end else begin
            unique case(fsm_st_r)

            (IDLE): begin
                // wait for a rising edge on stf_det_i
                if (stf_det_rising) begin
                    acf_re_sum <= 'd0;
                    acf_im_sum <= 'd0;
                    fsm_st_r  <= ACF_SKIP;
                    acf_cnt_r <= COUNT_WIDTH'(0);
                end
            end

            (ACF_SKIP): begin
                // wait for NUM_ACF_SKIPS samples to go by.
                if (acf_valid_i) begin
                    if (acf_cnt_r == (NUM_ACF_SKIPS - 1)) begin
                        fsm_st_r   <= ACF_SUM;
                        acf_cnt_r  <= COUNT_WIDTH'(0);
                        acf_re_sum <= 'd0;
                        acf_im_sum <= 'd0;
                    end else begin
                        acf_cnt_r <= acf_cnt_r + COUNT_WIDTH'(1);
                    end
                end
            end

            (ACF_SUM): begin
                // hold a running sum of the next 64 acf samples
                if (acf_valid_i) begin
                    acf_re_sum <= acf_re_sum + SUM_WIDTH'(acf_re_i);
                    acf_im_sum <= acf_im_sum + SUM_WIDTH'(acf_im_i);
                    if (acf_cnt_r == (NUM_ACF_SAMPLES -1)) begin
                        fsm_st_r <= HOLD;
                        done_r   <= 1'b1;
                    end else begin
                        acf_cnt_r <= acf_cnt_r + COUNT_WIDTH'(1);
                    end
                end
            end

            (HOLD): begin
                done_r <= 1'b0;
                // wait for stf_det_i to deassert for at least NUM_ACF_HOLDS updates
                if (stf_det_i) begin
                    acf_cnt_r <= COUNT_WIDTH'(0);
                end else if (acf_valid_i) begin
                    if (acf_cnt_r == (NUM_ACF_HOLDS - 1)) begin
                        fsm_st_r  <= IDLE;
                    end else begin
                        acf_cnt_r <= acf_cnt_r + COUNT_WIDTH'(1);
                    end
                end
            end

            endcase
        end
    end

// Actually average the sum of Re{} and Im{} so we can keep resource usage low when instantiating the vectoring mode CORDICs.
    localparam int NUM_SHIFTED_BITS = $clog2(NUM_ACF_SAMPLES);
    localparam int SHIFTED_WIDTH    = SUM_WIDTH - NUM_SHIFTED_BITS;

    logic signed [SHIFTED_WIDTH-1:0] acf_re_avg;
    logic signed [SHIFTED_WIDTH-1:0] acf_im_avg;
    assign acf_re_avg = (acf_re_sum >>> NUM_SHIFTED_BITS);
    assign acf_im_avg = (acf_im_sum >>> NUM_SHIFTED_BITS);

// Vectoring Mode CORDIC
    logic signed [15:0] acf_angle; // BAR16
    logic               acf_angle_valid;
    cordic #(
    	.NUM_STAGES     ( 14 ),
    	.BAR_ANGLE_WIDTH( 16 ),
    	.VECTOR_WIDTH   ( 36 )
     ) I_cordic_cfo (
    	.clk_i  (clk_i),
    	.rstn_i (rstn_i),
    	.vmode_i(1'b1),  // 1'b1 means vectoring mode
    	.z_i    (16'sd0),  // this input ignored in vectoring mode
    	.en_i   (done_r),
    	.x_i    (acf_re_avg),
    	.y_i    (acf_im_avg),
    	// output vectors not needed
    	.x_o    (),
    	.y_o    (),
    	// z_o is our acf_angle here
    	.z_o    (acf_angle),
    	.valid_o(acf_angle_valid)
    );

    assign cfo_angle_o = acf_angle;
    assign cfo_valid_o = acf_angle_valid;

endmodule : cfo_coarse_est

`default_nettype wire

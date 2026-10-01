// Synchronous FIFO that can be sized to 2^N

`timescale 1ns/1ps
`default_nettype none

module std_sync_fifo #(
    parameter int FIFO_DEPTH = 16,  // Must be a power of two!!
    parameter int FIFO_WIDTH = 8
) (
    input wire clk_i,
    input wire rstn_i,

    // Read Bus
    input wire rd_en_i,
    output wire [FIFO_WIDTH-1:0] rd_data_o,

    // Write Bus
    input wire wr_en_i,
    input wire [FIFO_WIDTH-1:0] wr_data_i,

    // Status & Misc
    output wire empty_o,
    output wire full_o
);

// pointers need to be 1 bit wider than required to track wrap around
    localparam int PTR_SIZE = $clog2(FIFO_DEPTH) + 1;
    logic [PTR_SIZE-1:0] rd_ptr_r;
    logic [PTR_SIZE-1:0] wr_ptr_r;

// determine if the fifo is full or empty
    logic fifo_empty;
    assign fifo_empty = (rd_ptr_r == wr_ptr_r);

    logic fifo_full, ptr_msb_different, ptr_no_msb_same;
    assign fifo_full            = (ptr_msb_different & ptr_no_msb_same);
    assign ptr_msb_different    = (rd_ptr_r[PTR_SIZE-1] ^ wr_ptr_r[PTR_SIZE-1]);
    assign ptr_no_msb_same      = (rd_ptr_r[PTR_SIZE-2:0] == wr_ptr_r[PTR_SIZE-2:0]);

// determine if the read/write actually goes through
    logic actually_read, actually_write;
    assign actually_read  = (rd_en_i & ~fifo_empty);
    assign actually_write = (wr_en_i & ~fifo_full); 


// Read/Write Logic
    logic [FIFO_DEPTH-1:0][FIFO_WIDTH-1:0] fifo_mem_r;
    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            fifo_mem_r <= '0;
            rd_ptr_r   <= '0;
            wr_ptr_r   <= '0;
        end else begin
            // read/write can happen simultaneously

            if (actually_read) begin
                rd_ptr_r <= rd_ptr_r + PTR_SIZE'(1);
            end

            if (actually_write) begin
                wr_ptr_r                             <= wr_ptr_r + PTR_SIZE'(1);
                fifo_mem_r[ wr_ptr_r[PTR_SIZE-2:0] ] <= wr_data_i;
            end
        end
    end

// MLIO Assignments
    assign rd_data_o = fifo_mem_r[ rd_ptr_r[PTR_SIZE-2:0] ]; // read data appears 1 cc after rd_en_i asserts, consumer should flop it anyways so not a big deal
    assign empty_o   = fifo_empty;
    assign full_o    = fifo_full;

// Instantiation Assertions
`ifndef SYNTHESIS
    initial begin
        assert (FIFO_DEPTH >= 2)
            else $fatal(1, "std_sync_fifo: FIFO_DEPTH parameter '%0d' is not larger than one", FIFO_DEPTH);
        
        assert ( (FIFO_DEPTH & (FIFO_DEPTH - 1)) == 0 )
            else $fatal(1, "std_sync_fifo: FIFO_DEPTH parameter '%0d' is not a clean power of two", FIFO_DEPTH);
    end
`endif

endmodule : std_sync_fifo
`default_nettype wire
`timescale 1ns / 1ps

module output_datapath #(
    parameter N = 4,
    parameter PE_OUT_WIDTH = 32,
    parameter OUTPUT_WIDTH = 4
)(
    input clk,
    input reset,

    input load_out,
    input shift,

    input src_ready,
    input dest_valid,

    input [PE_OUT_WIDTH*N*N-1:0] systolic_output,

    output [OUTPUT_WIDTH-1:0] final_data_out,
    output sh_count_done,
    output tx_two_done
);

    // ------------------------------------------------------------
    // Width calculations
    // ------------------------------------------------------------

    localparam TOTAL_OUTPUT_WIDTH = PE_OUT_WIDTH * N * N;
    localparam NUM_TRANSFERS      = TOTAL_OUTPUT_WIDTH / OUTPUT_WIDTH;

    // For N=4:
    // TOTAL_OUTPUT_WIDTH = 32*4*4 = 512
    // OUTPUT_WIDTH       = 4
    // NUM_TRANSFERS      = 512/4 = 128

    wire [TOTAL_OUTPUT_WIDTH-1:0] buffer_to_feeder;
    wire [OUTPUT_WIDTH-1:0] feeder_to_rv;


    // ------------------------------------------------------------
    // Buffer
    // ------------------------------------------------------------

    reg_def #(
        .WIDTH(TOTAL_OUTPUT_WIDTH)
    ) buffer (
        .x(systolic_output),
        .enable(1'b1),
        .clk(clk),
        .clear(reset),
        .y(buffer_to_feeder)
    );


    // ------------------------------------------------------------
    // Data Feeder
    //
    // 512-bit matrix result
    //        ↓
    // 128 × 4-bit transfers
    //
    // MSB-first behavior is inherited from data_feeder.
    // ------------------------------------------------------------

    data_feeder #(
        .IN_WIDTH(TOTAL_OUTPUT_WIDTH),
        .OUT_WIDTH(OUTPUT_WIDTH)
    ) feeder_i_e (
        .clk(clk),
        .data_in(buffer_to_feeder),
        .shift(shift),
        .reset(reset),
        .load(load_out),
        .data_out(feeder_to_rv)
    );


    // ------------------------------------------------------------
    // Shift Counter
    //
    // 128 transfers:
    // count = 0 ... 127
    // ------------------------------------------------------------



    controlled_counter #(
        .COUNT_WIDTH($clog2(NUM_TRANSFERS)),
        .COUNT_LIMIT(NUM_TRANSFERS)
    ) sh_counter_output_datapath (
        .clk(clk),
        .reset(reset),
        .enable(tx_two_done),
        .count_done(sh_count_done)
    );

    // ------------------------------------------------------------
    // Ready / Valid Protocol
    //
    // Now the datapath transfers 4 bits at a time.
    // ------------------------------------------------------------

    rv_protocol #(
        .N(OUTPUT_WIDTH),
        .DATA_WIDTH(1)
    ) rv_two (
        .clk(clk),
        .reset(reset),
        .valid(dest_valid),
        .ready(src_ready),
        .data_in(feeder_to_rv),
        .data_out(final_data_out),
        .tx_done(tx_two_done)
    );

endmodule
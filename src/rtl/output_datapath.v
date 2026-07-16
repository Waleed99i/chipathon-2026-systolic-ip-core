`timescale 1ns / 1ps

module output_datapath #(
    parameter N = 4,
    parameter PE_OUT_WIDTH = 32,
    parameter OUTPUT_WIDTH = 64
)(
    input clk,
    input reset,

    input load_out,
    input shift,

    input src_ready,
    input dest_valid,

    input [PE_OUT_WIDTH*N*N-1:0] systolic_output, //PE_OUT_WIDTH*N*N=32*4*4=512 here for 4x4 systolic

    output [OUTPUT_WIDTH-1:0] final_data_out,
    output sh_count_done,
    output tx_two_done
);

wire [PE_OUT_WIDTH*N*N-1:0] buffer_to_feeder;
wire [OUTPUT_WIDTH-1:0] feeder_to_rv;

localparam NUM_TRANSFERS = (PE_OUT_WIDTH*N*N)/OUTPUT_WIDTH;

// Buffer
reg_def #(
    .WIDTH(PE_OUT_WIDTH*N*N)
) buffer (
    .x(systolic_output),
    .enable(1'b1),
    .clk(clk),
    .clear(reset),
    .y(buffer_to_feeder)
);

// Data Feeder
data_feeder #(
    .IN_WIDTH(PE_OUT_WIDTH*N*N), //512
    .OUT_WIDTH(OUTPUT_WIDTH) //64
) feeder_i_e (
    .clk(clk),
    .data_in(buffer_to_feeder),
    .shift(shift),
    .reset(reset),
    .load(load_out),
    .data_out(feeder_to_rv)
);

// Shift Counter
controlled_counter #(
    .COUNT_WIDTH($clog2(NUM_TRANSFERS)),
    .COUNT_LIMIT(NUM_TRANSFERS-1)
) sh_counter_output_datapath (
    .clk(clk),
    .reset(reset),
    .enable(shift),
    .count_done(sh_count_done),
    .count()
);

// Ready/Valid Protocol
rv_protocol #(
    .N(OUTPUT_WIDTH/16),
    .DATA_WIDTH(16)
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
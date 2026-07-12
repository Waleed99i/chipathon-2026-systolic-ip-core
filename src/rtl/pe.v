`timescale 1ns / 1ps

module pe #(
    parameter DATA_WIDTH = 16,
    parameter ACC_WIDTH  = 32,
    parameter N = 4
)(
    input clk,
    input reset,
    input valid,

    input  [DATA_WIDTH-1:0] a_in,
    input  [DATA_WIDTH-1:0] b_in,

    output [DATA_WIDTH-1:0] a_out,
    output [DATA_WIDTH-1:0] b_out,

    output [ACC_WIDTH-1:0] y_out,
    output valid_out
);

// Internal Signals

wire [DATA_WIDTH-1:0] a_reg;
wire [DATA_WIDTH-1:0] b_reg;

wire [ACC_WIDTH-1:0] mac_result;
wire mac_done;

// Input Registers

reg_def #(
    .WIDTH(DATA_WIDTH)
)
reg_a(
    .clk(clk),
    .rst(reset),
    .en(valid),
    .d(a_in),
    .q(a_reg)
);

reg_def #(
    .WIDTH(DATA_WIDTH)
)
reg_b(
    .clk(clk),
    .rst(reset),
    .en(valid),
    .d(b_in),
    .q(b_reg)
);

assign a_out = a_reg;
assign b_out = b_reg;

// Approximate MAC


fp16_to_q16_16_approximate_mac mac(

    .clk(clk),
    .reset(reset),
    .valid(valid),

    .a(a_reg),
    .b(b_reg),

    .result(mac_result),
    .done(mac_done)

);

//Counter

counter #(
    .N(N)
)
u_counter(

    .clk(clk),
    .reset(reset),
    .done(mac_done),

    .valid_out(valid_out)

);

// Output Register

reg_def #(
    .WIDTH(ACC_WIDTH)
)
reg_y(

    .clk(clk),
    .rst(reset),
    .en(valid_out),

    .d(mac_result),
    .q(y_out)

);

endmodule
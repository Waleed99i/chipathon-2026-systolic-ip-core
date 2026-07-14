`timescale 1ns/1ps

module pe #(
    parameter N = 4
)(
    input clk,
    input reset,
    input valid,

    input  [15:0] A_in,
    input  [15:0] B_in,

    output [31:0] y_out,

    output [15:0] A_out,
    output [15:0] B_out,

    output done,
    output valid_out
);

    wire [31:0] y;

    fp16_to_q16_16_approximate_mac mac_unit_inst (
        .clk(clk),
        .reset(reset),
        .valid(valid),
        .a(A_in),
        .b(B_in),
        .result(y),
        .done(done)
    );

    reg_def #(.WIDTH(16)) reg_A (
        .x(A_in),
        .enable(done),
        .clk(clk),
        .clear(reset),
        .y(A_out)
    );

    reg_def #(.WIDTH(16)) reg_B (
        .x(B_in),
        .enable(done),
        .clk(clk),
        .clear(reset),
        .y(B_out)
    );

    counter #(
        .N(N)
    ) counter (
        .clk(clk),
        .reset(reset),
        .done(done),
        .valid_out(valid_out)
    );

    reg_def #(.WIDTH(32)) reg_y (
        .x(y),
        .enable(valid_out),
        .clk(clk),
        .clear(reset),
        .y(y_out)
    );

endmodule
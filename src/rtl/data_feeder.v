`timescale 1ns/1ps

module data_feeder #(
    parameter N = 4,
    parameter OUT_WIDTH = 16,
    parameter IN_WIDTH = OUT_WIDTH*(2*N-1) // for 4x4 it will be 16*7=112 
)(
    input clk,
    input reset,
    input load,
    input shift,

    input [IN_WIDTH-1:0] data_in,

    output [OUT_WIDTH-1:0] data_out
);

    reg [IN_WIDTH-1:0] shift_reg;

    always @(posedge clk or posedge reset or posedge load) begin
        if (reset) begin
            shift_reg <= {IN_WIDTH{1'b0}};
        end
        else if (load) begin
            shift_reg <= data_in; // Load all 112 (16*2N-1) bits
        end
        else if (shift) begin
            shift_reg <= shift_reg << OUT_WIDTH; // shifts 16b
        end
    end

    assign data_out = shift_reg[IN_WIDTH-1 -: OUT_WIDTH];

endmodule
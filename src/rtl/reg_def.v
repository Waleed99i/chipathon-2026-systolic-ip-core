`timescale 1ns / 1ps

module reg_def #(
    parameter WIDTH = 16
)(
    input clk,
    input clear,
    input enable,
    input [WIDTH-1:0] x,
    output reg [WIDTH-1:0] y
);

always @(posedge clk) begin
    if (clear)
        y <= {WIDTH{1'b0}};
    else if (enable)
        y <= x;
end

endmodule

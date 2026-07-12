`timescale 1ns / 1ps

module counter #(
    parameter N = 4
)(
    input clk,
    input reset,
    input done,

    output reg valid_out  // its like en_y ( in the design)
);

localparam COUNT_MAX = (2*N)-1;  // 7 for 4x4 (N=4) systolic array
reg [$clog2(2*N)-1:0] count;
always @(posedge clk or posedge reset) begin
    if(reset) begin
        count <= 0;
    end
    else if(done) begin
        if(count == COUNT_MAX)
            count <= 0;
        else
            count <= count + 1'b1;
    end
end
always @(*) begin

    if(reset)
        valid_out = 1'b0;
    else
        valid_out = (count == COUNT_MAX);

end

endmodule






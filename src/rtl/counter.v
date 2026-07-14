`timescale 1ns / 1ps

module counter #(
    parameter N = 4
)(
    input clk,
    input reset,
    input done,

    output reg valid_out
);

localparam COUNT_MAX = (2*N)-1;

reg [$clog2(2*N)-1:0] count;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        count <= 0;
        valid_out <= 1'b0;
    end
    else begin
        // valid_out is a one-clock pulse
        valid_out <= 1'b0;

        if(done) begin

            if(count == COUNT_MAX) begin
                count <= 0;
            end
            else begin
                count <= count + 1'b1;
            end

            // Assert valid when reaching the final count
            if(count == COUNT_MAX-1)
                valid_out <= 1'b1;

        end
    end
end

endmodule
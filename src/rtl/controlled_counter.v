`timescale 1ns/1ps

module controlled_counter #(
    parameter COUNT_LIMIT = 4 //for parametrized systolic
)(
    input clk,
    input reset,
    input enable,

    output reg count_done,
    output reg [$clog2(COUNT_LIMIT+1)-1:0] count
);

always @(posedge clk or posedge reset) begin

    if(reset) begin
        count <= 0;
        count_done <= 1'b0;
    end
    else begin

        count_done <= 1'b0;

        if(enable) begin

            if(count == COUNT_LIMIT-1) begin
                count <= 0;
                count_done <= 1'b1;
            end
            else begin
                count <= count + 1'b1;
            end

        end

    end

end

endmodule
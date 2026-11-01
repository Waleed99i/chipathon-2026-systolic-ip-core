`timescale 1ns / 1ps

module counter #(
    parameter N = 4
)(
    input clk,
    input reset,
    input done,
    output reg valid_out
);

    // A complete NxN output-stationary systolic multiply needs
    // 3N-2 compute steps:
    //
    //   N       -> inner-product terms
    //   N-1     -> row skew
    //   N-1     -> column skew / array drain
    //
    // For N=4: 3*4-2 = 10 steps.
    localparam COUNT_MAX = (3*N)-2;

    // Must be wide enough for the new COUNT_MAX.
    localparam COUNT_WIDTH = $clog2(COUNT_MAX + 1);

    reg [COUNT_WIDTH-1:0] count;

    always @(posedge clk or posedge reset) begin

        if (reset) begin
            count     <= 0;
            valid_out <= 1'b0;
        end

        else begin

            // one-clock completion pulse
            valid_out <= 1'b0;

            if (done) begin

                if (count == COUNT_MAX) begin
                    count <= 0;
                end
                else begin
                    count <= count + 1'b1;
                end

                // Assert on the final required compute event.
                if (count == COUNT_MAX-1)
                    valid_out <= 1'b1;

            end
        end
    end

endmodule
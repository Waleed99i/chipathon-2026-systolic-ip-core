`timescale 1ns / 1ps

module fp16_to_q16_16_approximate_mac(
    input  [15:0] a,
    input  [15:0] b,
    output [31:0] result,
    output reg done,

    input clk,
    input reset,
    input valid
);

    // Approximate FP16 multiplier result
    wire [15:0] mul_res;


    // Direct FP16 -> Q16.16 conversion
    //
    // Previous design:
    //
    // FP16 multiplier result
    //        |
    //        v
    //      Q8.8
    //        |
    //        v
    //   sign extend + << 8
    //        |
    //        v
    //      Q16.16 accumulator
    //
    // This caused every individual product greater than +127.99609375
    // (or below -128) to saturate before accumulation.
    //
    // New design:
    //
    // FP16 multiplier result
    //        |
    //        v
    //      Q16.16
    //        |
    //        v
    //      Q16.16 accumulator
    wire signed [31:0] q16_16;


    // Accumulator
    reg signed [31:0] sum;


    // FSM
    localparam IDLE       = 2'd0,
               ACCUMULATE = 2'd1,
               DONE       = 2'd2;

    reg [1:0] state = IDLE;


    // MAC control
    always @(posedge clk) begin

        if (reset) begin

            sum   <= 32'sd0;
            done  <= 1'b0;
            state <= IDLE;

        end
        else begin

            if (state == IDLE) begin

                if (valid) begin
                    state <= ACCUMULATE;
                end

            end


            if (state == ACCUMULATE) begin

                // Directly accumulate the Q16.16 product.
                //
                // OLD:
                //
                // sum <= sum + {{8{q8_8[15]}}, q8_8, 8'd0};
                //
                // NEW:
                //
                // No Q8.8 bottleneck.

                sum <= sum + q16_16;

                done <= 1'b1;

                state <= DONE;

            end


            if (state == DONE) begin

                if (valid == 1'b0) begin

                    done  <= 1'b0;
                    state <= IDLE;

                end

            end

        end

    end


    // Approximate FP16 multiplier
    fp16_approximate_multiplier_wrapper mul (
        .a(a),
        .b(b),
        .result(mul_res)
    );


    // FP16 -> Q16.16 converter
    fp16_to_q16_16 u_convert (
        .fp16_in(mul_res),
        .q16_16_out(q16_16)
    );


    // MAC result
    assign result = sum;
endmodule
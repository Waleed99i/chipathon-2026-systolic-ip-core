`timescale 1ns / 1ps

module fp16_multiplier_exception (
    input [9:0] mA, mB,
    input [4:0] eA, eB,
    output out_exception
);
    assign out_exception = ({eA, mA} == 15'b0 || {eB, mB} == 15'b0 || eA == 5'b11111 || eB == 5'b11111) ? 1'b1 : 1'b0;
endmodule

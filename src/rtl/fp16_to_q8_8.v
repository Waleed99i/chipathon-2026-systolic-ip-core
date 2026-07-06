`timescale 1ns / 1ps

module fp16_to_q8_8 (
    input [15:0] fp16,
    output reg [15:0] q8_8,
    output reg ovf
);
    wire sign = fp16[15];
    wire [4:0] exp = fp16[14:10];
    wire [9:0] frac = fp16[9:0];

    wire [15:0] mantissa = {5'b0, 1'b1, frac};

    wire signed [6:0] exp_true = {2'b00, exp} - 7'sd15;


    wire signed [6:0] shift = exp_true - 7'sd2;

    reg [15:0] shifted_val;

    always @(*) begin
        ovf = 1'b0;
        q8_8 = 16'd0;
        shifted_val = 16'd0;

        if (exp == 5'h1F) begin
            ovf = 1'b1;
            q8_8 = 16'd0;
        end else if (exp_true > 7'sd6) begin
            if (exp_true == 7'sd7 && sign && frac == 10'd0) begin
                q8_8 = 16'h8000;
            end else begin
                ovf = 1'b1;
                q8_8 = sign ? 16'h8000 : 16'h7FFF;
            end
        end else begin
            if (shift >= 0) begin
                shifted_val = mantissa << shift;
            end else begin
                shifted_val = mantissa >> (-shift);
            end
            q8_8 = sign ? -shifted_val : shifted_val;
        end
    end
    
endmodule
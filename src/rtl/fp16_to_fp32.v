`timescale 1ns / 1ps

module fp16_to_fp32 (
    input  wire [15:0] fp16_in,  // 16-bit Half-Precision Input
    output reg  [31:0] fp32_out  // 32-bit Single-Precision Output
);

    // Slice input into IEEE 754 components
    wire        sign16 = fp16_in[15];
    wire [4:0]  exp16  = fp16_in[14:10];
    wire [9:0]  mant16 = fp16_in[9:0];

    // Internal intermediate signals
    reg [3:0]   lzc;             // Leading Zero Count for subnormals (0 to 9)
    reg [7:0]   exp32;
    reg [22:0]  mant32;
    reg [19:0]  shifted_mant;    // Expanded register for normalization shift

    always @* begin
        // --- STAGE 1: Priority Encoder for Subnormal Leading Zero Count ---
        if      (mant16[9]) lzc = 4'd0;
        else if (mant16[8]) lzc = 4'd1;
        else if (mant16[7]) lzc = 4'd2;
        else if (mant16[6]) lzc = 4'd3;
        else if (mant16[5]) lzc = 4'd4;
        else if (mant16[4]) lzc = 4'd5;
        else if (mant16[3]) lzc = 4'd6;
        else if (mant16[2]) lzc = 4'd7;
        else if (mant16[1]) lzc = 4'd8;
        else                lzc = 4'd9;

        // --- STAGE 2: Case Classification & Transformation ---
        if (exp16 == 5'd0) begin
            if (mant16 == 10'd0) begin
                // Case 1: Zero
                exp32  = 8'd0;
                mant32 = 23'd0;
            end else begin
                // Case 2: Subnormal (Normalize to FP32 Normal)
                // New Exponent = 113 - LZC
                exp32  = 8'd113 - {4'd0, lzc};
                
                // Shift mantissa left by (lzc + 1) to strip leading zeros and implicit '1',
                // then align to MSB of the 23-bit FP32 mantissa field.
                shifted_mant = {mant16, 10'd0} << (lzc + 1'b1);
                mant32       = {shifted_mant[19:10], 13'd0};
            end
        end 
        else if (exp16 == 5'd31) begin
            // Case 3 & 4: Infinity or NaN
            exp32  = 8'd255;
            mant32 = {mant16, 13'd0}; // Preserve NaN payload if mant16 != 0
        end 
        else begin
            // Case 5: Normal Number
            // New Exponent = exp16 - 15 + 127 = exp16 + 112
            exp32  = {3'd0, exp16} + 8'd112;
            mant32 = {mant16, 13'd0}; // Pad with 13 trailing zeros
        end

        // --- STAGE 3: Final Output Packing ---
        fp32_out = {sign16, exp32, mant32};
    end

endmodule
`timescale 1ns / 1ps

module fp32_to_fp16 (
    input  wire [31:0] fp32_in,  // 32-bit Single-Precision Input
    output reg  [15:0] fp16_out  // 16-bit Half-Precision Output
);

    // Unpack FP32 IEEE 754 components
    wire        sign32 = fp32_in[31];
    wire [7:0]  exp32  = fp32_in[30:23];
    wire [22:0] mant32 = fp32_in[22:0];

    // Signed unbiased exponent calculation
    wire signed [9:0] e_unbiased = $signed({2'b00, exp32}) - 10'sd127;

    // Internal pipeline signals
    reg [4:0]  exp16;
    reg [9:0]  mant16;
    reg [24:0] align_sig;        // 25-bit aligned significand: {implicit_bit, mant32, extra_zero}
    reg [4:0]  r_shift;          // Right-shift amount for subnormal denormalization
    reg        round_bit;
    reg        sticky_bit;
    reg        lsb_bit;

    always @* begin
        // Default initializations
        exp16  = 5'd0;
        mant16 = 10'd0;

        // --- STAGE 1: Special Case Handling (NaN, Infinity, Zero) ---
        if (exp32 == 8'd255) begin
            if (mant32 == 23'd0) begin
                // Infinity
                exp16  = 5'd31;
                mant16 = 10'd0;
            end else begin
                // NaN (Preserve MSB of mantissa to keep Quiet/Signaling status)
                exp16  = 5'd31;
                mant16 = {1'b1, mant32[21:13]};
            end
        end 
        else if (exp32 == 8'd0 && mant32 == 23'd0) begin
            // Exact Zero
            exp16  = 5'd0;
            mant16 = 10'd0;
        end 
        
        // --- STAGE 2: Overflow Handling ---
        else if (e_unbiased > 10'sd15) begin
            // Overflow to Infinity
            exp16  = 5'd31;
            mant16 = 10'd0;
        end 
        
        // --- STAGE 3: Underflow to Zero ---
        else if (e_unbiased < -10'sd24) begin
            // Complete underflow to zero
            exp16  = 5'd0;
            mant16 = 10'd0;
        end 
        
        // --- STAGE 4: Normal & Subnormal Conversion with Rounding ---
        else begin
            if (e_unbiased >= -10'sd14) begin
                // Case A: FP16 Normal Number
                exp16     = e_unbiased + 10'sd15;
                // Extract top 10 bits of mantissa, plus rounding bits
                mant16    = mant32[22:13];
                lsb_bit   = mant32[13];
                round_bit = mant32[12];
                sticky_bit= |mant32[11:0];
            end else begin
                // Case B: Underflow to FP16 Subnormal (Denormalization)
                exp16     = 5'd0;
                // Calculate required right shift: (-14 - e_unbiased), ranges from 1 to 10
                r_shift   = -10'sd14 - e_unbiased;
                
                // Construct 24-bit significand with implicit '1', append 1 zero at LSB for shifting
                align_sig = {1'b1, mant32, 1'b0} >> r_shift;
                
                mant16    = align_sig[23:14];
                lsb_bit   = align_sig[14];
                round_bit = align_sig[13];
                // Sticky bit is OR of all remaining bits shifted out
                sticky_bit= |align_sig[12:0] | (|({1'b1, mant32, 1'b0} & ((1 << r_shift) - 1)));
            end

            // Apply Round-to-Nearest, Tie-to-Even (RNE)
            if (round_bit && (sticky_bit || lsb_bit)) begin
                if (mant16 == 10'h3FF) begin
                    mant16 = 10'd0;
                    exp16  = exp16 + 5'd1; // Handle rounding overflow (can promote subnormal to normal!)
                end else begin
                    mant16 = mant16 + 10'd1;
                end
            end
        end

        // --- STAGE 5: Final Output Packing ---
        fp16_out = {sign32, exp16, mant16};
    end

endmodule
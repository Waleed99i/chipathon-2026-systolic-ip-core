`timescale 1ns / 1ps

module q16_16_to_fp32 (
    input  wire [31:0] q_in,   // Signed Q16.16 Fixed-Point Input
    output reg  [31:0] fp_out    // IEEE 754 Single-Precision Float Output
);

    // Internal pipeline registers/signals
    reg        sign;
    reg [31:0] abs_val;
    reg [4:0]  lzc;              // Leading Zero Count (0 to 31)
    reg [7:0]  exp;              // Biased Exponent (8 bits)
    reg [63:0] shifted_val;      // 64-bit shift register for normalization
    reg [22:0] mantissa;         // 23-bit Mantissa
    reg        round_bit;
    reg        sticky_bit;

    always @(*) begin
        // --- STAGE 1: Zero Check & Magnitude Extraction ---
        sign = q_in[31];
        abs_val = sign ? (~q_in + 1'b1) : q_in;

        if (abs_val == 32'd0) begin
            fp_out = 32'd0;      // Handle exactly zero
        end else begin
            // --- STAGE 2: Priority Encoder for Leading Zero Count (LZC) ---
            if      (abs_val[31]) lzc = 5'd0;
            else if (abs_val[30]) lzc = 5'd1;
            else if (abs_val[29]) lzc = 5'd2;
            else if (abs_val[28]) lzc = 5'd3;
            else if (abs_val[27]) lzc = 5'd4;
            else if (abs_val[26]) lzc = 5'd5;
            else if (abs_val[25]) lzc = 5'd6;
            else if (abs_val[24]) lzc = 5'd7;
            else if (abs_val[23]) lzc = 5'd8;
            else if (abs_val[22]) lzc = 5'd9;
            else if (abs_val[21]) lzc = 5'd10;
            else if (abs_val[20]) lzc = 5'd11;
            else if (abs_val[19]) lzc = 5'd12;
            else if (abs_val[18]) lzc = 5'd13;
            else if (abs_val[17]) lzc = 5'd14;
            else if (abs_val[16]) lzc = 5'd15; // Bit 16 is 2^0 (1.0)
            else if (abs_val[15]) lzc = 5'd16;
            else if (abs_val[14]) lzc = 5'd17;
            else if (abs_val[13]) lzc = 5'd18;
            else if (abs_val[12]) lzc = 5'd19;
            else if (abs_val[11]) lzc = 5'd20;
            else if (abs_val[10]) lzc = 5'd21;
            else if (abs_val[9])  lzc = 5'd22;
            else if (abs_val[8])  lzc = 5'd23;
            else if (abs_val[7])  lzc = 5'd24;
            else if (abs_val[6])  lzc = 5'd25;
            else if (abs_val[5])  lzc = 5'd26;
            else if (abs_val[4])  lzc = 5'd27;
            else if (abs_val[3])  lzc = 5'd28;
            else if (abs_val[2])  lzc = 5'd29;
            else if (abs_val[1])  lzc = 5'd30;
            else                  lzc = 5'd31;

            // --- STAGE 3: Exponent Calculation ---
            // Formula: Exponent = 127 + (31 - LZC) - 16 = 142 - LZC
            exp = 8'd142 - {3'd0, lzc};

            // --- STAGE 4: Normalization Shift & Mantissa Extraction ---
            // Place abs_val in upper 32 bits of 64-bit word (bit 48 corresponds to 2^0).
            // Shifting left by LZC moves the leading '1' to bit 63 (the implicit bit).
            shifted_val = {abs_val, 32'd0} << lzc;

            // Extract 23 bits immediately below bit 63
            mantissa   = shifted_val[62:40];
            round_bit  = shifted_val[39];
            sticky_bit = |shifted_val[38:0]; // Logical OR of all remaining bits

            // --- STAGE 5: Round-to-Nearest-Even & Packing ---
            if (round_bit && (sticky_bit || mantissa[0])) begin
                if (mantissa == 23'h7FFFFF) begin
                    mantissa = 23'd0;
                    exp      = exp + 8'd1;   // Handle mantissa overflow
                end else begin
                    mantissa = mantissa + 23'd1;
                end
            end

            fp_out = {sign, exp, mantissa};
        end
    end

endmodule
// Verilog-2001 Synthesizable Q16.16 to IEEE FP16 Converter
module q16_16_to_fp16 (
    input  wire [31:0] q_in,   // 32-bit signed Q16.16 (1 sign, 15 int, 16 frac)
    output reg  [15:0] fp_out  // 16-bit IEEE FP16 (1 sign, 5 exp, 10 mantissa)
);
    reg        sign;
    reg [31:0] abs_val;
    reg [4:0]  pos;            // Holds position of leading '1' (0 to 31)
    reg        is_zero;
    
    reg [4:0]  eff_pos;
    reg [31:0] shifted_val;
    reg [4:0]  exp_pre;
    reg [9:0]  mant_pre;
    reg        round_bit;
    
    reg [10:0] rounded_mant;
    reg [4:0]  final_exp;
    reg [9:0]  final_mant;

    integer i; // Loop variable must be declared outside the loop in standard Verilog

    always @* begin
        // 1. Extract Sign and calculate Absolute Value
        sign    = q_in[31];
        abs_val = sign ? (~q_in + 1'b1) : q_in;
        is_zero = (abs_val == 32'd0);

        // 2. Leading One Detection (Synthesizable Priority Encoder)
        // Scans from LSB (0) to MSB (31). Higher set bits naturally overwrite 
        // lower positions, avoiding the need for non-synthesizable jump statements.
        pos = 5'd0;
        for (i = 0; i <= 31; i = i + 1) begin
            if (abs_val[i]) begin
                pos = i[4:0];
            end
        end

        // 3. Normalization and Alignment
        eff_pos = (pos >= 5'd2) ? pos : 5'd2;
        
        shifted_val = abs_val << (5'd31 - eff_pos);
        
        mant_pre  = shifted_val[30:21];
        round_bit = shifted_val[20];
        
        exp_pre = (pos >= 5'd2) ? (pos - 5'd1) : 5'd0;

        // 4. Rounding (Round-Half-Up)
        rounded_mant = {1'b0, mant_pre} + round_bit;

        // 5. Overflow Handling from Rounding
        if (rounded_mant[10]) begin
            final_exp  = exp_pre + 5'd1;
            final_mant = 10'd0;
        end else begin
            final_exp  = exp_pre;
            final_mant = rounded_mant[9:0];
        end

        // 6. Pack the Final Output
        if (is_zero) begin
            fp_out = 16'd0;
        end else begin
            fp_out = {sign, final_exp, final_mant};
        end
    end
endmodule
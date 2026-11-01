module fp16_to_q16_16 (
    input  wire [15:0] fp16_in,
    output reg  signed [31:0] q16_16_out
);

    reg        sign;
    reg [4:0]  exponent;
    reg [9:0]  fraction;

    reg [10:0] mantissa;
    reg signed [7:0] unbiased_exp;

    reg [47:0] magnitude;

    integer shift_amount;

    always @(*) begin

        sign     = fp16_in[15];
        exponent = fp16_in[14:10];
        fraction = fp16_in[9:0];

        q16_16_out = 32'sd0;
        magnitude  = 48'd0;
        mantissa   = 11'd0;
        unbiased_exp = 0;
        shift_amount = 0;

        // Zero
        if (exponent == 5'd0 && fraction == 10'd0) begin

            q16_16_out = 32'sd0;

        end

        // Infinity / NaN
        //
        // Saturate infinities.
        // NaN currently maps to zero.

        else if (exponent == 5'h1F) begin

            if (fraction != 10'd0) begin
                q16_16_out = 32'sd0;
            end
            else if (sign) begin
                q16_16_out = 32'sh8000_0000;
            end
            else begin
                q16_16_out = 32'sh7FFF_FFFF;
            end

        end

        // Subnormal FP16
        // value = fraction/1024 * 2^-14

        else if (exponent == 5'd0) begin

            // Q16.16 scaling:
            //
            // fraction * 2^-24 * 2^16
            // = fraction / 256

            magnitude = fraction >> 8;

            if (sign)
                q16_16_out = -$signed(magnitude[31:0]);
            else
                q16_16_out =  $signed(magnitude[31:0]);

        end

        // Normal FP16
        //
        // value =
        //   (1024 + fraction)/1024 * 2^(exponent-15)
        //
        // Q16.16 =
        //   value * 65536
        //
        // therefore:
        //
        // q = mantissa * 2^(exponent - 9)

        else begin

            mantissa = {1'b1, fraction};

            unbiased_exp = $signed({1'b0, exponent}) - 15;

            shift_amount = unbiased_exp + 6;

            if (shift_amount >= 0)
                magnitude = mantissa << shift_amount;
            else
                magnitude = mantissa >> (-shift_amount);


            // Saturation to signed Q16.16
            if (!sign) begin

                if (magnitude > 48'h0000_7FFF_FFFF)
                    q16_16_out = 32'sh7FFF_FFFF;
                else
                    q16_16_out = $signed(magnitude[31:0]);

            end
            else begin

                if (magnitude > 48'h0000_8000_0000)
                    q16_16_out = 32'sh8000_0000;
                else
                    q16_16_out = -$signed(magnitude[31:0]);

            end

        end

    end

endmodule
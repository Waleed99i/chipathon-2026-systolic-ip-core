`timescale 1ns / 1ps

module fp16_multiplier_exponent (
    input [4:0] exponentA,
    input [4:0] exponentB,
    input carry,
    output [4:0] exponent 
);

    wire [5:0] add_exponent = exponentA + exponentB;
    reg [4:0] tmp_exponent;
    reg [5:0] norm_exponent;
    
    always @(*) begin
        if(add_exponent[5:4] == 2'b00) begin
            tmp_exponent = 5'd0; // underflow
            norm_exponent = 6'd0;
        end else begin
            norm_exponent = add_exponent - 6'd15;
            
            if(norm_exponent[5]) tmp_exponent = 5'b11111; // overflow
            else tmp_exponent = norm_exponent + carry;
        end
    end
    
    assign exponent = tmp_exponent;
endmodule

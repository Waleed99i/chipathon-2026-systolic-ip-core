`timescale 1ns / 1ps

module fp16_approximate_multiplier_wrapper(
    input [15:0] a,
    input [15:0] b,
    output [15:0] result
);
    fp16_approximate_multiplier u_fplm(.sA(a[15]), 
	.sB(b[15]),
    .eA(a[14:10]),
    .eB(b[14:10]),
	.mA(a[9:0]),
    .mB(b[9:0]),
    .sP(result[15]),
	.eP(result[14:10]),
	.mP(result[9:0]));
endmodule

module log_multiplier (
    input [9:0] mA, mB,
    output [9:0] mP,
    output msb_ab);
    
    wire [10:0] mALog = (mA[9] == 1'b0) ? {1'b0, mA[9:0]} : {2'b11, mA[9:1]};
    wire [10:0] mBLog = (mB[9] == 1'b0) ? {1'b0, mB[9:0]} : {2'b11, mB[9:1]};
    
    wire [10:0] mABLog = mALog + mBLog;
    
    assign mP = (mABLog[10] == 0) ? mABLog[9:0] : {mABLog[8:0], 1'b0};
    assign msb_ab = mABLog[10];
    
endmodule

module log_carry (
    input msb_a, msb_b, msb_ab,
    output carry
);
    assign carry = ~(~(msb_a & msb_b) & (~(msb_a | msb_b) | msb_ab));
endmodule

module fp16_approximate_multiplier_multiply(
    input [9:0] mA, mB,
    
    output [9:0] mP,
    output carry
    );
    
    wire msb_ab;
    log_multiplier u_logm(.mA(mA), .mB(mB), .mP(mP), .msb_ab(msb_ab));
    
    log_carry u_carry(.msb_a(mA[9]), .msb_b(mB[9]), .msb_ab(msb_ab), 
    .carry(carry));
endmodule

module fp16_approximate_multiplier(
    input sA,
    input sB,
    input [4:0] eA,
    input [4:0] eB,
    input [9:0] mA,
    input [9:0] mB,
    
    output sP,
    output [4:0] eP,
    output [9:0] mP
    );
    
    wire carry;
    wire [9:0] mRes;
    wire [4:0] eRes;
    wire exception;
    
    fp16_multiplier_exponent u_exponent(.exponentA(eA), .exponentB(eB), .carry(carry),
    .exponent(eRes));
    
    fp16_approximate_multiplier_multiply u_mul(.mA(mA), .mB(mB), .carry(carry), .mP(mRes));
    fp16_multiplier_exception u_exception(.mA(mA), .mB(mB), .eA(eA), .eB(eB), .out_exception(exception));

    assign sP = sA ^ sB;
    assign eP = exception ? 5'd0 : eRes;
    assign mP = exception ? 10'd0 : mRes;
endmodule
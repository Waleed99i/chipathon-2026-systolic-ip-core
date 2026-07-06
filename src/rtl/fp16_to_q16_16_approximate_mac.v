`timescale 1ns / 1ps

module fp16_to_q16_16_approximate_mac(
	input [15:0] a,
	input [15:0] b,
	output [31:0] result,
	output reg done,
	
	input clk,
	input reset,
	input valid
);
	wire [15:0] mul_res;
    wire [15:0] q8_8;

	reg [31:0] sum;
	
	localparam IDLE = 2'd0, ACCUMULATE = 2'd1, DONE = 2'd2;
	reg [1:0] state = IDLE;
	
	always @(posedge clk) begin
	   if(reset) begin 
	    	sum <= 32'd0;
			done <= 1'd0;
			state <= IDLE;
	   end else begin
	       if(state == IDLE) begin
	           if(valid) begin
	            	state <= ACCUMULATE;
	           end
			end if(state == ACCUMULATE) begin
				sum <= sum + {{8{q8_8[15]}}, q8_8, 8'd0};
				done <= 1'd1;

				state <= DONE;
			end if(state == DONE) begin
				if(valid == 0) begin
					done <= 1'd0;
					state <= IDLE;
				end
			end
	   end
	end
	
	fp16_approximate_multiplier_wrapper mul(.a(a), .b(b), .result(mul_res));
	fp16_to_q8_8 u_convert(.fp16(mul_res), .q8_8(q8_8));
	
	assign result = sum;
endmodule
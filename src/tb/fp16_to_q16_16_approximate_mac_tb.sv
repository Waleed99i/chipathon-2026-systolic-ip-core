`timescale 1ns / 1ps

module fp16_to_q16_16_approximate_mac_tb();
	reg [15:0] a = 16'd0;
	reg [15:0] b = 16'd0;
	wire [31:0] result;
	wire done;
	
	reg clk = 0;
	reg reset = 0;
	reg valid = 0;

	reg [31:0] q16_in;
	reg [31:0] fp32_in;
	wire [15:0] fp16_out;

	wire [31:0] fp32_out_q16;

	always #1 clk = ~clk;

	task fp32_to_fp16(input [31:0] fp32, output [15:0] fp16);
	begin
		fp32_in = fp32;
		#1
		fp16 = fp16_out;
	end
	endtask

	task q16_16_to_fp32(input [31:0] q16, output [31:0] fp32);
	begin
		q16_in = q16;
		#1
		fp32 = fp32_out_q16;
	end
	endtask

	task reset_mac();
    begin
        reset = 1;
        @(posedge clk);
        @(posedge clk);
        reset = 0;
        $display("MAC is reset");
    end
    endtask

	task run_mac(input [31:0] in1, in2, output [31:0] out);
	logic [31:0] fp32;
	logic [15:0] fp16;
	
    begin
		fp32_to_fp16(in1, fp16);
		#1 a = fp16;

		fp32_to_fp16(in2, fp16);
		#1 b = fp16;

		@(posedge clk);
    	valid <= 1;

    	@(posedge done);
		q16_16_to_fp32(result,fp32);
		#1 out = fp32;

		@(posedge clk);
		valid <= 0;
    end
    endtask

	logic [31:0] out_mac_fp32 = $shortrealtobits(0.725);
	logic [31:0] in_mac1, in_mac2;
	logic [31:0] prev_out_mac_fp32;
	initial begin
        $dumpfile("build/fp16_to_q16_16_approximate_mac_tb.vcd"); 
        $dumpvars(0, fp16_to_q16_16_approximate_mac_tb);
		#1
		reset_mac();
		#2
		for (int i = 0; i < 100; i++) begin
			#1
			q16_16_to_fp32(result, prev_out_mac_fp32);
			in_mac1 = out_mac_fp32;
			in_mac2 = $shortrealtobits(0.56);
			run_mac(in_mac1, in_mac2, out_mac_fp32);
            #1
            $display("(%f * %f) + %f = %f (expected = %f)", $bitstoshortreal(in_mac1), 
			$bitstoshortreal(in_mac2), $bitstoshortreal(prev_out_mac_fp32), $bitstoshortreal(out_mac_fp32), 
			($bitstoshortreal(in_mac1) * $bitstoshortreal(in_mac2)) + $bitstoshortreal(prev_out_mac_fp32));
        end
		#10

		$finish();
	end

	fp16_to_q16_16_approximate_mac u_module(.a(a), 
		.b(b), 
		.result(result), 
		.done(done), 
		.clk(clk),
		.reset(reset),
		.valid(valid)
	);

    q16_16_to_fp32 u_q16_16_to_fp32(.q_in(q16_in), .fp_out(fp32_out_q16));
	fp32_to_fp16 u_fp16_to_fp32(.fp32_in(fp32_in), .fp16_out(fp16_out));
endmodule
`timescale 1ns/1ps
module converter_tb;
  reg [15:0] bits;
  wire signed [31:0] converted;
  reg [31:0] expected [0:65535];
  integer i;
  fp16_to_q16_16 dut(.fp16_in(bits), .q16_16_out(converted));
  initial begin
    $readmemh("converter_expected.hex", expected);
    for (i=0; i<65536; i=i+1) begin
      bits=i; #1;
      if (converted !== expected[i])
        $fatal(1,"Converter mismatch: fp16=%h actual=%h expected=%h",bits,converted,expected[i]);
    end
    $display("CONVERTER PASS: all 65536 FP16 encodings");
    $finish;
  end
  initial begin #70000; $fatal(1,"Converter timeout"); end
endmodule

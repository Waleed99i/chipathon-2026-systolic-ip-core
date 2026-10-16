`timescale 1ns/1ps
module counter_tb;
  logic clk = 0;
  logic rst = 1;
  logic done = 0;
  wire valid_out;
  always #5 clk = ~clk;
  counter #(.N(4)) DUT (.clk(clk), .reset(rst), .done(done), .valid_out(valid_out));

  // Drive away from the active edge and inspect after nonblocking updates.
  task automatic pulse_and_check(input logic expected);
    @(negedge clk); done = 1;
    @(posedge clk); #1;
    if (valid_out !== expected)
      $fatal(1, "counter: expected valid_out=%b, got %b", expected, valid_out);
    @(negedge clk); done = 0;
    @(posedge clk); #1;
    if (valid_out !== 0) $fatal(1, "counter: valid_out did not clear on idle cycle");
  endtask

  initial begin
    repeat (2) @(posedge clk);
    #1;
    if (valid_out !== 0) $fatal(1, "counter: invalid reset output");
    @(negedge clk); rst = 0;
    repeat (9) pulse_and_check(0);
    pulse_and_check(1); // 3*N-2 = 10 compute events for N=4.
    pulse_and_check(0); // The next event wraps count from 10 to 0.
    repeat (9) pulse_and_check(0);
    pulse_and_check(1);
    @(negedge clk); rst = 1;
    @(posedge clk); #1;
    if (valid_out !== 0) $fatal(1, "counter: reset failed after a completed burst");
    $display("COUNTER PASS: two 10-step bursts, wrap event, idle and reset checks");
    $finish;
  end
  initial begin
    #20000;
    $fatal(1, "TIMEOUT: counter test");
  end
endmodule

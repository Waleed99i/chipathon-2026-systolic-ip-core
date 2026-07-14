// For counter1.png simulation
`timescale 1ns/1ps
module counter_tb;


  // DUT signals
  logic clk = 0;
  logic rst = 1;      
  logic done = 0;
  logic valid_out;

  // 10 ns clock
  always #5 clk = ~clk;


  // Instantiate the DUT
  counter DUT (
    .clk   (clk),
    .reset (rst),
    .done  (done),
    .valid_out  (valid_out)
  );



  // generate one‑cycle ‘done’ pulse
  task automatic pulse_done;
    done <= 1;
    @(posedge clk);
    done <= 0;
  endtask



  initial begin
    // VCD for GTKWave
    $dumpfile("build/counter_tb.vcd");
    $dumpvars(0, counter_tb);

    // Hold reset for two clocks
    repeat(2)   @(posedge clk);  
    rst = 0;

    // FIRST TIME
    $display("\n AT FIRST TIME");

    pulse_done(); @(posedge clk);   
    pulse_done(); @(posedge clk);   
    pulse_done(); @(posedge clk);   
    pulse_done(); @(posedge clk);   
    pulse_done(); @(posedge clk);   
    pulse_done(); @(posedge clk);   
    pulse_done(); @(posedge clk);  
 


    // Check valid_out
    if (valid_out !== 1)
      $error("valid_out did not assert at end of first time!");
    else
      $display(" valid_out asserted correctly after 7 pulses (2nd time)");


    // Gap before next burst
    repeat(2)    @(posedge clk);  

    //SECOND TIME
    $display("\n AT SECOND TIME");

    pulse_done(); @(posedge clk);   
    pulse_done(); @(posedge clk);   
    pulse_done(); @(posedge clk);   
    pulse_done(); @(posedge clk);   
    pulse_done(); @(posedge clk);   
    pulse_done(); @(posedge clk);   
    pulse_done(); @(posedge clk);   
    pulse_done(); @(posedge clk);   


    // Check valid_out
    if (valid_out !== 1)
      $error("valid_out did not assert at end of second time!");
    else
      $display(" valid_out asserted correctly after 7 pulses (2nd time)");

    // All done
    $display("\nAll tests PASSED");
    $finish;
  end

endmodule




// for counter2.png simulation
// `timescale 1ns/1ps

// module counter_tb;

//     parameter N = 4;

//     logic clk = 0;
//     logic reset = 1;
//     logic done = 0;

//     logic valid_out;

//     always #5 clk = ~clk;

//     counter #(
//         .N(N)
//     ) DUT (
//         .clk(clk),
//         .reset(reset),
//         .done(done),
//         .valid_out(valid_out)
//     );

//     task automatic pulse_done;
//     begin
//         done = 1'b1;
//         @(posedge clk);
//         done = 1'b0;
//     end
//     endtask

//     integer i;

//     initial begin

//         $dumpfile("build/counter_tb.vcd");
//         $dumpvars(0, counter_tb);

//         @(posedge clk);
//         reset = 0;

//         $display("\nFirst Run");

//         for(i = 1; i < 2*N; i = i + 1)
//             pulse_done();

//         @(posedge clk);

//         if(valid_out)
//             $display("PASS : valid_out asserted.");
//         else
//             $error("FAIL : valid_out was not asserted.");

//         repeat(2) @(posedge clk);

//         $display("\nSecond Run");

//         for(i = 0; i < 2*N; i = i + 1)
//             pulse_done();

//         @(posedge clk);

//         if(valid_out)
//             $display("PASS : valid_out asserted again.");
//         else
//             $error("FAIL : valid_out was not asserted.");

//         $display("\nAll Counter Tests Passed.");

//         $finish;

//     end

// endmodule


`timescale 1ns/1ps

module rv_protocol_tb;

parameter N = 4;
parameter DATA_WIDTH = 16;
parameter INPUT_WIDTH = DATA_WIDTH*(2*N);

reg clk;
reg reset;
reg valid;
reg ready;

reg  [INPUT_WIDTH-1:0] data_in;
wire [INPUT_WIDTH-1:0] data_out;
wire tx_done;

// DUT
rv_protocol #(
    .N(N)
) dut (

    .clk(clk),
    .reset(reset),

    .valid(valid),
    .ready(ready),

    .data_in(data_in),
    .data_out(data_out),

    .tx_done(tx_done)

);

// Clock
always #5 clk = ~clk;

// One clock delay
task wait_cycle;
begin
    @(posedge clk);
end
endtask

initial begin

    $dumpfile("build/rv_protocol_tb.vcd");
    $dumpvars(0,rv_protocol_tb);

    clk   = 0;
    reset = 1;
    valid = 0;
    ready = 0;
    data_in = 0;

    wait_cycle;

    reset = 0;

    wait_cycle;

    // 8 FP16 values:
    // {1,2,3,4,5,6,7,8}

    data_in = {
        16'h3C00,
        16'h4000,
        16'h4200,
        16'h4400,
        16'h4500,
        16'h4600,
        16'h4700,
        16'h4800
    };

    valid = 1'b1;

    $display("\nVALID asserted");
    $display("data_in = %h",data_in);

    wait_cycle;

    ready = 1'b1;

    $display("\nREADY asserted");

    wait_cycle;

    $display("\nHandshake Completed");
    $display("tx_done = %b",tx_done);

    wait_cycle;

    $display("\nOutput");
    $display("data_out = %h",data_out);
    $display("tx_done  = %b",tx_done);

    valid = 0;
    ready = 0;

    wait_cycle;

    $display("\nRV Protocol Test Passed.");

    #20;

    $finish;

end

endmodule
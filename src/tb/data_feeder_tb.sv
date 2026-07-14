`timescale 1ns/1ps

module data_feeder_tb;

parameter N = 4;
parameter DATA_WIDTH = 16;
parameter IN_WIDTH = DATA_WIDTH*(2*N-1);

reg clk = 0;
reg reset = 0;
reg shift = 0;
reg load = 0;

reg [IN_WIDTH-1:0] data_in;
reg [IN_WIDTH-1:0] data_to_be_fed;

wire [DATA_WIDTH-1:0] data_out;

// Clock generation
always #5 clk = ~clk;

// DUT
data_feeder #(
    .N(N)
) DUT (
    .clk(clk),
    .reset(reset),
    .load(load),
    .shift(shift),
    .data_in(data_in),
    .data_out(data_out)
);

// Shift out all values
task shift_all;
    integer i;
begin

    for(i=0; i<(2*N-1); i=i+1) begin

        shift = 1'b1;
        @(posedge clk);
        shift = 1'b0;

        $display("Time=%0t | Element %0d | data_out = 0x%h",
                 $time, i+1, data_out);

        @(posedge clk);

    end

end
endtask


// Load one burst then shift everything out
task feed_burst;

input [IN_WIDTH-1:0] values;
input [127:0] label;

begin

    repeat(2) @(posedge clk);

    $display("\n%s", label);

    data_in = values;
    load = 1'b1;

    @(posedge clk);

    load = 1'b0;

    shift_all();

end

endtask


initial begin

    $dumpfile("build/data_feeder_tb.vcd");
    $dumpvars(0,data_feeder_tb);

    reset = 1;
    @(posedge clk);
    reset = 0;

    // Burst 1
    // {1.0,2.0,3.0,4.0,5.0,6.0,7.0}
    data_to_be_fed = {
        16'h3C00,
        16'h4000,
        16'h4200,
        16'h4400,
        16'h4500,
        16'h4600,
        16'h4700
    };

    feed_burst(data_to_be_fed,"Burst 1");

    repeat(3) @(posedge clk);

    reset = 1;
    @(posedge clk);
    reset = 0;

    // Burst 2
    // {8.0,7.0,6.0,5.0,4.0,3.0,2.0}
    data_to_be_fed = {
        16'h4800,
        16'h4700,
        16'h4600,
        16'h4500,
        16'h4400,
        16'h4200,
        16'h4000
    };

    feed_burst(data_to_be_fed,"Burst 2");

    $display("\nData Feeder Test Passed.");

    $finish;

end

endmodule
`timescale 1ns/1ps

module input_datapath_tb;

parameter N = 4;
parameter DATA_WIDTH = 16;

localparam INPUT_WIDTH  = DATA_WIDTH*(2*N);
localparam OUTPUT_WIDTH = DATA_WIDTH*(2*N-1);

// Clock and Reset
reg clk;
reg reset;

// DUT Inputs
reg [INPUT_WIDTH-1:0] data_in;
reg src_valid;
reg dest_ready;
reg next_row;
reg next_col;

// DUT Outputs
wire load_in_done;
wire tx_one_done;

wire [OUTPUT_WIDTH-1:0] A_r1;
wire [OUTPUT_WIDTH-1:0] A_r2;
wire [OUTPUT_WIDTH-1:0] A_r3;
wire [OUTPUT_WIDTH-1:0] A_r4;

wire [OUTPUT_WIDTH-1:0] B_c1;
wire [OUTPUT_WIDTH-1:0] B_c2;
wire [OUTPUT_WIDTH-1:0] B_c3;
wire [OUTPUT_WIDTH-1:0] B_c4;


// DUT
input_datapath #(
    .N(N),
    .DATA_WIDTH(DATA_WIDTH)
) dut (

    .clk(clk),
    .reset(reset),

    .data_in(data_in),

    .src_valid(src_valid),
    .dest_ready(dest_ready),

    .next_row(next_row),
    .next_col(next_col),

    .load_in_done(load_in_done),
    .tx_one_done(tx_one_done),

    .A_r1(A_r1),
    .A_r2(A_r2),
    .A_r3(A_r3),
    .A_r4(A_r4),

    .B_c1(B_c1),
    .B_c2(B_c2),
    .B_c3(B_c3),
    .B_c4(B_c4)

);


// 100 MHz clock
always #5 clk = ~clk;


// Wait one clock
task wait_cycle;
begin
    @(posedge clk);
end
endtask


initial begin

    $dumpfile("build/input_datapath_tb.vcd");
    $dumpvars(0,input_datapath_tb);

    clk = 0;
    reset = 1;

    src_valid = 0;
    dest_ready = 0;

    next_row = 0;
    next_col = 0;

    data_in = 0;

    wait_cycle;
    reset = 0;
    wait_cycle;


    // Upper 64 bits = Row (1.0 2.0 3.0 4.0)
    // Lower 64 bits = Column (5.0 6.0 7.0 8.0)

    data_in = {
                16'h3C00,16'h4000,16'h4200,16'h4400,
                16'h4500,16'h4600,16'h4700,16'h4800
              };

    src_valid = 1'b1;

    wait_cycle;

    dest_ready = 1'b1;

    wait_cycle;

    $display("\nHandshake Completed");
    $display("tx_one_done = %b",tx_one_done);

    $display("Row Data = %h",dut.protocol_out[INPUT_WIDTH-1:DATA_WIDTH*N]);
    $display("Col Data = %h",dut.protocol_out[(DATA_WIDTH*N)-1:0]);


    src_valid = 0;
    dest_ready = 0;

    wait_cycle;


    $display("\nLoading Row/Column Registers");

    repeat(N) begin

        next_row = 1'b1;
        next_col = 1'b1;

        wait_cycle;

        next_row = 1'b0;
        next_col = 1'b0;

        wait_cycle;

        $display("row_count = %0d   col_count = %0d",
                    dut.row_count,
                    dut.col_count);

    end


    wait(load_in_done);

    $display("\nload_in_done asserted.\n");


    $display("A_r1 = %h",A_r1);
    $display("A_r2 = %h",A_r2);
    $display("A_r3 = %h",A_r3);
    $display("A_r4 = %h",A_r4);

    $display("");

    $display("B_c1 = %h",B_c1);
    $display("B_c2 = %h",B_c2);
    $display("B_c3 = %h",B_c3);
    $display("B_c4 = %h",B_c4);


    $display("\nInput Datapath Test Completed.");

    #50;
    $finish;

end

endmodule
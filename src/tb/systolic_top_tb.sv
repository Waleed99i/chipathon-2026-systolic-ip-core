`timescale 1ns/1ps

module systolic_top_tb;

reg clk;
reg reset;
reg valid_in;
reg [127:0] data_in;
reg src_valid;
reg src_ready;

wire [63:0] final_data_out;
wire done_matrix_mult;
wire tx_one_done;
wire tx_two_done;

systolic dut(
    .clk(clk),
    .reset(reset),
    .valid_in(valid_in),
    .data_in(data_in),
    .src_valid(src_valid),
    .src_ready(src_ready),
    .final_data_out(final_data_out),
    .done_matrix_mult(done_matrix_mult),
    .tx_one_done(tx_one_done),
    .tx_two_done(tx_two_done)
);

always #5 clk = ~clk;

initial begin
    clk = 0;
    reset = 1;
    valid_in = 0;
    src_valid = 0;
    src_ready = 0;
    data_in = 0;

    #20;
    reset = 0;

    //-------------------------
    // Start transaction
    //-------------------------
    @(posedge clk);
    valid_in = 1;

    @(posedge clk);
    valid_in = 0;

    //-------------------------
    // Send one 128-bit packet
    //-------------------------

    data_in = {
        16'd1,16'd2,16'd3,16'd4,
        16'd5,16'd6,16'd7,16'd8
    };

    src_valid = 1;

    @(posedge tx_one_done);
    src_valid = 0;

    $display("Input accepted.");

    //-------------------------
    // Receive outputs
    //-------------------------

    repeat(8)
    begin
        src_ready = 1;

        @(posedge tx_two_done);

        $display("%t Output = %h",$time,final_data_out);

        @(posedge clk);
        src_ready = 0;
    end

    wait(done_matrix_mult);

    $display("DONE");

    #100;
    $finish;

end

endmodule
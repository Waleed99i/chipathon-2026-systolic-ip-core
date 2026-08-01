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
    // after #20; reset = 0;

// Monitor important signals
    $monitor("%0t: state=%d, dest_ready=%b, src_valid=%b, tx_one_done=%b, load_in_done=%b",
    $time, dut.state, dut.dest_ready, src_valid, tx_one_done, dut.load_in_done);

//-------------------------
// Start transaction
//-------------------------
@(posedge clk);
valid_in = 1;
@(posedge clk);
valid_in = 0;

//-------------------------
// Send all 4 input packets (handshake on each)
//-------------------------
for (int i = 0; i < 4; i = i + 1) begin
    // Form one row and one column
    data_in = {
        16'(i*4+1), 16'(i*4+2), 16'(i*4+3), 16'(i*4+4),   // row i
        16'(i*4+5), 16'(i*4+6), 16'(i*4+7), 16'(i*4+8)    // col i
    };
    src_valid = 1'b1;

    // Wait for this packet to be accepted (tx_one_done pulse)
    @(posedge tx_one_done);
    src_valid = 1'b0;

    // Small gap between packets (optional but safe)
    @(negedge clk);
end
$display("All inputs accepted.");

//-------------------------
// Receive outputs
//-------------------------
repeat(8) begin
    src_ready = 1;

    @(posedge tx_two_done);

    $display("%t Output = %h", $time, final_data_out);

    @(posedge clk);
    src_ready = 0;
end

wait(done_matrix_mult);

$display("DONE");

#100;
$finish;
end

endmodule
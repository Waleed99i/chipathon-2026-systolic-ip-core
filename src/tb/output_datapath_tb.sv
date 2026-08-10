`timescale 1ns/1ps

module output_datapath_tb;

parameter N = 4;
parameter PE_OUT_WIDTH = 32;
parameter OUTPUT_WIDTH = 4;

localparam TOTAL_WIDTH = 512;
localparam NUM_TRANSFERS = 128;

reg clk;
reg reset;

reg load_out;
reg shift;

reg src_ready;
reg dest_valid;

reg [TOTAL_WIDTH-1:0] systolic_output;

wire [OUTPUT_WIDTH-1:0] final_data_out;
wire sh_count_done;
wire tx_two_done;

integer i;

reg [OUTPUT_WIDTH-1:0] expected;

// ------------------------------------------------------------
// Clock
// ------------------------------------------------------------

always #5 clk = ~clk;

// ------------------------------------------------------------
// DUT
// ------------------------------------------------------------

output_datapath #(
    .N(N),
    .PE_OUT_WIDTH(PE_OUT_WIDTH),
    .OUTPUT_WIDTH(OUTPUT_WIDTH)
) dut (
    .clk(clk),
    .reset(reset),
    .load_out(load_out),
    .shift(shift),
    .src_ready(src_ready),
    .dest_valid(dest_valid),
    .systolic_output(systolic_output),
    .final_data_out(final_data_out),
    .sh_count_done(sh_count_done),
    .tx_two_done(tx_two_done)
);

// ------------------------------------------------------------
// Reset
// ------------------------------------------------------------

task reset_dut;
begin
    reset = 1'b1;

    @(posedge clk);
    @(posedge clk);

    reset = 1'b0;

    @(posedge clk);
end
endtask

// ------------------------------------------------------------
// Load 512-bit result
// ------------------------------------------------------------

task load_data;
begin
    load_out = 1'b1;

    // Allow the buffer/feeder to see load
    @(posedge clk);
    #1;

    load_out = 1'b0;

    // Allow signals to settle
    @(posedge clk);
    #1;

    $display("");
    $display("After LOAD:");
    $display("buffer_to_feeder = %h", dut.buffer_to_feeder);
    $display("feeder_to_rv     = %h", dut.feeder_to_rv);
    $display("expected first   = %h", systolic_output[511:508]);
    $display("");

    if (dut.buffer_to_feeder !== systolic_output) begin
        $display("FAIL: buffer did not receive systolic output.");
        $finish;
    end

    if (dut.feeder_to_rv !== systolic_output[511:508]) begin
        $display("FAIL: feeder first nibble incorrect.");
        $display("Expected = %h", systolic_output[511:508]);
        $display("Got      = %h", dut.feeder_to_rv);
        $finish;
    end

    $display("PASS: buffer and feeder loaded correctly.");
end
endtask

// ------------------------------------------------------------
// Transfer one 4-bit value
// ------------------------------------------------------------

task do_transfer;
    input integer index;
    input [3:0] expected_data;

begin

    dest_valid = 1'b1;
    src_ready = 1'b1;

    // Wait for a clock edge with valid && ready
    @(posedge clk);

    #1;

    if (final_data_out !== expected_data) begin

        $display(
            "FAIL: transfer=%0d expected=%h got=%h",
            index,
            expected_data,
            final_data_out
        );

        $finish;

    end
    else begin

        $display(
            "PASS: transfer=%0d data=%h tx_done=%b",
            index,
            final_data_out,
            tx_two_done
        );

    end

    dest_valid = 1'b0;
    src_ready = 1'b0;

    @(posedge clk);

end
endtask

// ------------------------------------------------------------
// Shift to next 4-bit chunk
// ------------------------------------------------------------

task do_shift;
begin

    shift = 1'b1;

    @(posedge clk);

    shift = 1'b0;

    @(posedge clk);

end
endtask

// ------------------------------------------------------------
// Main test
// ------------------------------------------------------------

initial begin

    // Waveform
    $dumpfile("build/output_datapath_tb.vcd");
    $dumpvars(0, output_datapath_tb);

    // Clock initial value
    clk = 1'b0;

    // Inputs initial values
    reset = 1'b0;
    load_out = 1'b0;
    shift = 1'b0;
    src_ready = 1'b0;
    dest_valid = 1'b0;

    // --------------------------------------------------------
    // 512-bit test pattern
    // --------------------------------------------------------

    systolic_output = 512'hDEADBEEFCAFEBABE112233445566778899AABBCCDDEEFF00123456789ABCDEF013579BDFDEADBEEF2468ACE0FEDCBA980FEDCBA9876543211122334455667788;

    $display("");
    $display("==============================================");
    $display(" OUTPUT DATAPATH TEST");
    $display("==============================================");
    $display("Input width       = %0d bits", TOTAL_WIDTH);
    $display("Output width      = %0d bits", OUTPUT_WIDTH);
    $display("Number transfers  = %0d", NUM_TRANSFERS);
    $display("==============================================");
    $display("");

    // --------------------------------------------------------
    // Reset
    // --------------------------------------------------------

    reset_dut();

    // --------------------------------------------------------
    // Load systolic output into buffer
    // --------------------------------------------------------

    load_data();

    $display("Buffer:");
    $display("%h", dut.buffer_to_feeder);
    $display("");

    // --------------------------------------------------------
    // Transfer 128 x 4-bit chunks
    // --------------------------------------------------------

    for (i = 0; i < NUM_TRANSFERS; i = i + 1) begin

        // MSB-first expected nibble
        expected = systolic_output[511 - (i * 4) -: 4];

        do_transfer(i, expected);

        // Shift except after last transfer
        if (i < NUM_TRANSFERS - 1) begin
            do_shift();
        end

    end

    // --------------------------------------------------------
    // Counter completion
    // --------------------------------------------------------

    #1;

    if (sh_count_done !== 1'b1) begin

        $display("");
        $display("FAIL: sh_count_done is not asserted.");
        $display("");

    end
    else begin

        $display("");
        $display("PASS: sh_count_done asserted.");
        $display("");
    end

    $display("==============================================");
    $display(" OUTPUT DATAPATH TEST COMPLETE");
    $display("==============================================");

    #20;

    $finish;

end

endmodule

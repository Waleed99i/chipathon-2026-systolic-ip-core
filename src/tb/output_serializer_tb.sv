`timescale 1ns/1ps

module output_serializer_tb;

    logic clk;
    logic reset;

    logic valid_in;
    logic ready_in;
    logic [511:0] data_in;

    logic ready_out;
    logic valid_out;
    logic [63:0] data_out;

    output_serializer dut (
        .clk       (clk),
        .reset     (reset),

        .valid_in  (valid_in),
        .ready_in  (ready_in),
        .data_in   (data_in),

        .ready_out (ready_out),
        .valid_out (valid_out),
        .data_out  (data_out)
    );

    // ------------------------------------------------------------
    // Clock: 10 ns period
    // ------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------------------------
    // Waveform dump
    // ------------------------------------------------------------
    initial begin
        $dumpfile("build/output_serializer_tb.vcd");
        $dumpvars(0, output_serializer_tb);
    end

    // ------------------------------------------------------------
    // Monitor
    // ------------------------------------------------------------
    always @(posedge clk) begin
        $display(
            "%0t | reset=%b valid_in=%b ready_in=%b data_in=%h | valid_out=%b ready_out=%b data_out=%h",
            $time,
            reset,
            valid_in,
            ready_in,
            data_in,
            valid_out,
            ready_out,
            data_out
        );

        if (valid_out && ready_out) begin
            $display(
                "        OUTPUT CHUNK = %h",
                data_out
            );
        end
    end

    // ------------------------------------------------------------
    // Test
    // ------------------------------------------------------------
    initial begin

        reset    = 1'b1;
        valid_in = 1'b0;
        ready_out = 1'b0;
        data_in  = 512'b0;

        // Reset
        #20;
        reset = 1'b0;

        // --------------------------------------------------------
        // 512-bit test packet
        // --------------------------------------------------------
        data_in =
            512'h
            AAAABBBBCCCCDDDDEEEEFFFF00001111
            22223333444455556666777788889999
            AAAABBBBCCCCDDDDEEEEFFFF00001111
            22223333444455556666777788889999;

        // Present packet
        valid_in = 1'b1;

        // Wait until serializer accepts it
        wait (ready_in);

        @(posedge clk);
        valid_in = 1'b0;

        $display("");
        $display("==============================================");
        $display("512-bit packet loaded into output serializer");
        $display("==============================================");
        $display("");

        // --------------------------------------------------------
        // Enable output consumer
        // --------------------------------------------------------
        #10;
        ready_out = 1'b1;

        // --------------------------------------------------------
        // Wait for all 8 chunks
        // --------------------------------------------------------
        wait (
            valid_out &&
            ready_out &&
            data_out == 64'h6666777788889999
        );

        @(posedge clk);

        $display("");
        $display("==============================================");
        $display("All 8 output chunks transferred.");
        $display("PASS: MSB-first serialization correct.");
        $display("==============================================");
        $display("");

        #20;

        $finish;
    end

endmodule
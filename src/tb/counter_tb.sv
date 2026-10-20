`timescale 1ns/1ps

module counter_tb;

    // ------------------------------------------------------------------------
    // DUT signals
    // ------------------------------------------------------------------------

    logic clk = 0;
    logic rst = 1;
    logic done = 0;
    logic valid_out;


    // ------------------------------------------------------------------------
    // Clock: 10 ns period
    // ------------------------------------------------------------------------

    always #5 clk = ~clk;


    // ------------------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------------------

    counter #(
        .N(4)
    ) DUT (
        .clk       (clk),
        .reset     (rst),
        .done      (done),
        .valid_out (valid_out)
    );


    // ------------------------------------------------------------------------
    // Generate one-cycle done pulse
    // ------------------------------------------------------------------------

    task automatic pulse_done;
        begin
            @(negedge clk);
            done = 1'b1;

            @(posedge clk);
            #1;

            @(negedge clk);
            done = 1'b0;
        end
    endtask


    // ------------------------------------------------------------------------
    // Simulation timeout
    // ------------------------------------------------------------------------

    initial begin
        #10000;
        $fatal(1, "COUNTER TB TIMEOUT");
    end


    // ------------------------------------------------------------------------
    // Main test
    // ------------------------------------------------------------------------

    integer i;

    initial begin

        // VCD for GTKWave
        $dumpfile("build/counter_tb.vcd");
        $dumpvars(0, counter_tb);


        // --------------------------------------------------------------------
        // Reset
        // --------------------------------------------------------------------

        repeat (2)
            @(posedge clk);

        @(negedge clk);
        rst = 1'b0;


        // ====================================================================
        // FIRST RUN
        //
        // N = 4
        // COUNT_MAX = 3*N - 2 = 10
        //
        // valid_out must assert on the 10th done pulse.
        // ====================================================================

        $display("");
        $display("==============================================");
        $display(" FIRST RUN - EXPECT VALID AFTER 10 DONE PULSES");
        $display("==============================================");


        // First 9 pulses must NOT assert valid_out
        for (i = 1; i <= 9; i = i + 1) begin

            pulse_done();

            if (valid_out !== 1'b0)
                $fatal(
                    1,
                    "valid_out asserted too early after pulse %0d",
                    i
                );

            $display(
                "Pulse %0d: valid_out = %b",
                i,
                valid_out
            );

        end


        // 10th pulse must assert valid_out
        pulse_done();

        $display(
            "Pulse 10: valid_out = %b",
            valid_out
        );


        if (valid_out !== 1'b1)
            $fatal(
                1,
                "valid_out did not assert after 10 done pulses"
            );

        $display(
            "PASS: valid_out asserted correctly after 10 pulses."
        );


        // --------------------------------------------------------------------
        // Check that valid_out is only one clock pulse
        // --------------------------------------------------------------------

        @(posedge clk);
        #1;

        if (valid_out !== 1'b0)
            $fatal(
                1,
                "valid_out stayed asserted for more than one clock"
            );

        $display(
            "PASS: valid_out is a one-clock completion pulse."
        );


        // --------------------------------------------------------------------
        // Gap
        // --------------------------------------------------------------------

        repeat (2)
            @(posedge clk);


        // ====================================================================
        // SECOND RUN
        //
        // IMPORTANT:
        //
        // After first completion, current RTL leaves count = COUNT_MAX (10).
        //
        // Therefore:
        //
        // first done pulse: 10 -> 0
        // next 10 pulses : new computation
        //
        // Total = 11 done pulses before the next valid_out.
        // ====================================================================

        $display("");
        $display("==============================================");
        $display(" SECOND RUN - EXPECT VALID AFTER 11 DONE PULSES");
        $display("==============================================");


        // First pulse wraps count from 10 -> 0.
        pulse_done();

        if (valid_out !== 1'b0)
            $fatal(
                1,
                "valid_out incorrectly asserted during counter wrap"
            );

        $display(
            "Wrap pulse: valid_out = %b", valid_out
        );


        // Next 9 compute pulses must not assert valid_out.
        for (i = 1; i <= 9; i = i + 1) begin

            pulse_done();

            if (valid_out !== 1'b0)
                $fatal(
                    1,
                    "valid_out asserted too early on second run, compute pulse %0d",
                    i
                );

            $display(
                "Compute pulse %0d: valid_out = %b",
                i,
                valid_out
            );

        end


        // Final (10th compute / 11th total) pulse.
        pulse_done();

        $display(
            "Final pulse: valid_out = %b", valid_out
        );


        if (valid_out !== 1'b1)
            $fatal(
                1,
                "valid_out did not assert on second run"
            );

        $display(
            "PASS: valid_out asserted correctly on second run."
        );


        // --------------------------------------------------------------------
        // Check pulse width again
        // --------------------------------------------------------------------

        @(posedge clk);
        #1;

        if (valid_out !== 1'b0)
            $fatal(
                1,
                "valid_out stayed asserted after second run"
            );


        // --------------------------------------------------------------------
        // Final result
        // --------------------------------------------------------------------

        $display("");
        $display("==============================================");
        $display(" ALL COUNTER TESTS PASSED");
        $display(" COUNT_MAX = 10 FOR N = 4");
        $display("==============================================");
        $display("");


        #20;
        $finish;

    end

endmodule
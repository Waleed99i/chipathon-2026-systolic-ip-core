`timescale 1ns/1ps

module pe_tb;

    parameter N = 4;

    // Complete PE completion schedule
    localparam COUNT_MAX = (3*N)-2;


    // ------------------------------------------------------------------------
    // DUT inputs
    // ------------------------------------------------------------------------

    reg clk;
    reg reset;
    reg valid;

    reg [15:0] A_in;
    reg [15:0] B_in;


    // ------------------------------------------------------------------------
    // DUT outputs
    // ------------------------------------------------------------------------

    wire [31:0] y_out;

    wire [15:0] A_out;
    wire [15:0] B_out;

    wire done;
    wire valid_out;


    // ------------------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------------------

    pe #(
        .N(N)
    ) dut (
        .clk       (clk),
        .reset     (reset),
        .valid     (valid),

        .A_in      (A_in),
        .B_in      (B_in),

        .y_out     (y_out),

        .A_out     (A_out),
        .B_out     (B_out),

        .done      (done),
        .valid_out (valid_out)
    );


    // ------------------------------------------------------------------------
    // Clock
    // ------------------------------------------------------------------------

    always #5 clk = ~clk;


    // ------------------------------------------------------------------------
    // Input vectors
    //
    // 10 MAC transactions are used because valid_out now comes after
    // 3*N-2 = 10 done events for N=4.
    //
    // First 7 are the original values.
    // Last 3 are zero-valued MAC transactions so they do not alter the sum.
    // ------------------------------------------------------------------------

    reg [15:0] A_vals [0:COUNT_MAX-1];
    reg [15:0] B_vals [0:COUNT_MAX-1];

    integer i;


    // ------------------------------------------------------------------------
    // Timeout
    // ------------------------------------------------------------------------

    initial begin

        #10000;

        $fatal(
            1,
            "PE TB TIMEOUT"
        );

    end


    // ------------------------------------------------------------------------
    // Waveform
    // ------------------------------------------------------------------------

    initial begin

        $dumpfile(
            "build/pe_tb.vcd"
        );

        $dumpvars(
            0,
            pe_tb
        );

    end


    // ------------------------------------------------------------------------
    // Main test
    // ------------------------------------------------------------------------

    initial begin

        clk   = 1'b0;
        reset = 1'b1;
        valid = 1'b0;

        A_in = 16'h0000;
        B_in = 16'h0000;


        // ====================================================================
        // Original 7 FP16 input pairs
        // ====================================================================

        A_vals[0] = 16'h3C00; // 1.0
        A_vals[1] = 16'h4000; // 2.0
        A_vals[2] = 16'h4200; // 3.0
        A_vals[3] = 16'h4400; // 4.0
        A_vals[4] = 16'h4500; // 5.0
        A_vals[5] = 16'h4600; // 6.0
        A_vals[6] = 16'h4700; // 7.0


        B_vals[0] = 16'h4000; // 2.0
        B_vals[1] = 16'h4200; // 3.0
        B_vals[2] = 16'h4400; // 4.0
        B_vals[3] = 16'h4500; // 5.0
        B_vals[4] = 16'h4600; // 6.0
        B_vals[5] = 16'h4700; // 7.0
        B_vals[6] = 16'h4800; // 8.0


        // ====================================================================
        // Additional 3 MAC transactions
        //
        // Zero products keep the accumulated result unchanged while allowing
        // the counter to reach 10 completed MAC events.
        // ====================================================================

        A_vals[7] = 16'h0000;
        A_vals[8] = 16'h0000;
        A_vals[9] = 16'h0000;

        B_vals[7] = 16'h0000;
        B_vals[8] = 16'h0000;
        B_vals[9] = 16'h0000;


        // --------------------------------------------------------------------
        // Reset
        // --------------------------------------------------------------------

        repeat (2)
            @(posedge clk);

        @(negedge clk);

        reset = 1'b0;


        $display("");
        $display("==============================================");
        $display(" PE TEST - NEW 3N-2 SCHEDULE");
        $display(" N         = %0d", N);
        $display(" COUNT_MAX = %0d", COUNT_MAX);
        $display("==============================================");
        $display("");


        // ====================================================================
        // Execute all MAC transactions
        // ====================================================================

        for (
            i = 0;
            i < COUNT_MAX;
            i = i + 1
        ) begin


            // ---------------------------------------------------------------
            // Apply inputs and assert valid
            // ---------------------------------------------------------------

            @(negedge clk);

            A_in = A_vals[i];
            B_in = B_vals[i];

            valid = 1'b1;


            // MAC accepts transaction
            @(posedge clk);


            // Deassert valid
            @(negedge clk);

            valid = 1'b0;


            // ---------------------------------------------------------------
            // Wait for MAC done
            // ---------------------------------------------------------------

            wait (
                done == 1'b1
            );


            $display(
                "----------------------------------------------"
            );

            $display(
                "Event %0d / %0d",
                i + 1,
                COUNT_MAX
            );

            $display(
                "A_in      = 0x%h",
                A_in
            );

            $display(
                "B_in      = 0x%h",
                B_in
            );

            $display(
                "A_out     = 0x%h",
                A_out
            );

            $display(
                "B_out     = 0x%h",
                B_out
            );

            $display(
                "MAC y     = 0x%h",
                dut.y
            );

            $display(
                "done      = %b",
                done
            );


            // ---------------------------------------------------------------
            // IMPORTANT:
            //
            // Counter sees done on the NEXT positive edge.
            // Therefore valid_out must be checked after this edge.
            // ---------------------------------------------------------------

            @(posedge clk);

            #1;


            $display(
                "valid_out = %b",
                valid_out
            );


            // ---------------------------------------------------------------
            // Events 1..9:
            // valid_out must remain low
            // ---------------------------------------------------------------

            if (
                i < COUNT_MAX-1
            ) begin

                if (
                    valid_out !== 1'b0
                ) begin

                    $fatal(
                        1,
                        "valid_out asserted too early after event %0d",
                        i + 1
                    );

                end

            end


            // ---------------------------------------------------------------
            // Event 10:
            // valid_out must assert
            // ---------------------------------------------------------------

            else begin

                if (
                    valid_out !== 1'b1
                ) begin

                    $fatal(
                        1,
                        "valid_out did not assert after %0d completed MAC events",
                        COUNT_MAX
                    );

                end


                $display("");

                $display(
                    "PASS: valid_out asserted correctly after %0d done events.",
                    COUNT_MAX
                );

            end


            // ---------------------------------------------------------------
            // Wait until MAC done goes low again
            // ---------------------------------------------------------------

            wait (
                done == 1'b0
            );


            // Small gap before next transaction
            #20;

        end


        // ====================================================================
        // Check final PE output timing
        //
        // valid_out becomes 1 on one clock edge.
        //
        // reg_y sees that valid_out on the NEXT clock edge and captures y.
        // ====================================================================

        @(posedge clk);

        #1;


        $display("");
        $display("==============================================");
        $display(" FINAL PE OUTPUT");
        $display("==============================================");

        $display(
            "y_out = 0x%h",
            y_out
        );


        // --------------------------------------------------------------------
        // Ensure valid_out was a single-cycle pulse
        // --------------------------------------------------------------------

        if (
            valid_out !== 1'b0
        ) begin

            $fatal(
                1,
                "valid_out remained asserted for more than one clock"
            );

        end


        $display(
            "PASS: valid_out is a one-clock completion pulse."
        );


        // --------------------------------------------------------------------
        // y_out must no longer be zero
        // --------------------------------------------------------------------

        if (
            y_out === 32'h00000000
        ) begin

            $fatal(
                1,
                "y_out was not captured after valid_out"
            );

        end


        $display(
            "PASS: final accumulated MAC result captured into y_out."
        );


        // --------------------------------------------------------------------
        // Final result
        // --------------------------------------------------------------------

        $display("");
        $display("==============================================");
        $display(" ALL PE TESTS PASSED");
        $display(" valid_out asserted after 10 done events.");
        $display(" final y_out captured one clock later.");
        $display("==============================================");
        $display("");


        #20;

        $finish;

    end

endmodule
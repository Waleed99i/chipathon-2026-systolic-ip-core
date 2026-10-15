`timescale 1ns/1ps

module systolic_top_tb;

    // ========================================================================
    // Configuration
    // ========================================================================

    // Approximate MAC:
    // Result is allowed to differ from exact mathematical A x B.
    //
    // A result FAILS only if its relative error exceeds this limit.
    //
    // 15.0 = 15 percent maximum relative error.
    localparam real MAX_ERROR_PERCENT = 15.0;

    // Global simulation timeout.
    localparam integer TIMEOUT_NS = 100000;


    // ========================================================================
    // DUT signals
    // ========================================================================

    reg clk;
    reg reset;

    reg         valid_in;
    reg [127:0] data_in;

    reg src_valid;
    reg src_ready;

    wire [3:0] final_data_out;

    wire done_matrix_mult;
    wire tx_one_done;
    wire tx_two_done;


    // ========================================================================
    // DUT
    // ========================================================================

    systolic dut (
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


    // ========================================================================
    // Clock
    // ========================================================================

    always #5 clk = ~clk;


    // ========================================================================
    // Simulation timeout
    // ========================================================================

    initial begin

        #(TIMEOUT_NS);

        $display("");
        $display("==============================================================");
        $display(" FATAL: SIMULATION TIMEOUT");
        $display(" Simulation exceeded %0d ns.", TIMEOUT_NS);
        $display("==============================================================");

        $fatal(1, "Simulation timeout");

    end


    // ========================================================================
    // FP16 constants
    //
    // All values below are exactly representable as IEEE-754 FP16 inputs.
    // Any output difference therefore comes from the approximate multiplier
    // and subsequent arithmetic, not input representation error.
    // ========================================================================

    localparam [15:0] FP_1_50  = 16'h3E00;
    localparam [15:0] FP_2_25  = 16'h4080;
    localparam [15:0] FP_2_50  = 16'h4100;
    localparam [15:0] FP_3_25  = 16'h4280;
    localparam [15:0] FP_3_50  = 16'h4300;

    localparam [15:0] FP_4_25  = 16'h4440;
    localparam [15:0] FP_4_50  = 16'h4480;
    localparam [15:0] FP_4_75  = 16'h44C0;

    localparam [15:0] FP_5_25  = 16'h4540;
    localparam [15:0] FP_5_50  = 16'h4580;

    localparam [15:0] FP_6_25  = 16'h4640;
    localparam [15:0] FP_6_50  = 16'h4680;
    localparam [15:0] FP_6_75  = 16'h46C0;

    localparam [15:0] FP_7_25  = 16'h4740;
    localparam [15:0] FP_7_50  = 16'h4780;

    localparam [15:0] FP_8_25  = 16'h4820;
    localparam [15:0] FP_8_50  = 16'h4840;
    localparam [15:0] FP_8_75  = 16'h4860;

    localparam [15:0] FP_9_25  = 16'h48A0;
    localparam [15:0] FP_9_50  = 16'h48C0;

    localparam [15:0] FP_10_50 = 16'h4940;
    localparam [15:0] FP_10_75 = 16'h4960;

    localparam [15:0] FP_11_25 = 16'h49A0;


    // ========================================================================
    // Output storage
    //
    // 128 transfers × 4 bits = 512 bits
    //
    // 8 transfers × 4 bits = one 32-bit Q16.16 element
    // ========================================================================

    reg [3:0] output_chunks [0:127];


    // ========================================================================
    // Error tracking
    // ========================================================================

    integer error_count;


    // ========================================================================
    // Reconstruct one 32-bit Q16.16 matrix element
    // ========================================================================

    function automatic [31:0] get_output_element;

        input integer element_index;

        integer base;

        begin

            base = element_index * 8;

            get_output_element = {
                output_chunks[base + 0],
                output_chunks[base + 1],
                output_chunks[base + 2],
                output_chunks[base + 3],
                output_chunks[base + 4],
                output_chunks[base + 5],
                output_chunks[base + 6],
                output_chunks[base + 7]
            };

        end

    endfunction


    // ========================================================================
    // Convert signed Q16.16 to real
    // ========================================================================

    function automatic real q16_16_to_real;

        input [31:0] value;

        reg signed [31:0] signed_value;

        begin

            signed_value = value;

            q16_16_to_real =
                $itor(signed_value) / 65536.0;

        end

    endfunction


    // ========================================================================
    // Print Q16.16
    // ========================================================================

    task print_q16_16;

        input [31:0] value;

        real decimal_value;

        begin

            decimal_value =
                q16_16_to_real(value);

            $write("%0.4f", decimal_value);

        end

    endtask


    // ========================================================================
    // Print complete matrix
    // ========================================================================

    task print_output_matrix;

        integer row;
        integer col;
        integer index;

        reg [31:0] element;

        begin

            $display("");
            $display("==============================================================");
            $display(" APPROXIMATE SYSTOLIC OUTPUT MATRIX");
            $display(" Format: Q16.16");
            $display("==============================================================");
            $display("");

            for (row = 0; row < 4; row = row + 1) begin

                $write("[ ");

                for (col = 0; col < 4; col = col + 1) begin

                    index = row * 4 + col;

                    element =
                        get_output_element(index);

                    print_q16_16(element);

                    if (col != 3)
                        $write("  ");

                end

                $display(" ]");

            end

            $display("");

        end

    endtask


    // ========================================================================
    // Send one 128-bit input packet
    // ========================================================================

    task send_input_packet;

        input [127:0] packet;

        begin

            data_in   = packet;
            src_valid = 1'b1;

            while (!tx_one_done)
                @(posedge clk);

            @(posedge clk);

            src_valid = 1'b0;

        end

    endtask


    // ========================================================================
    // Receive one 4-bit output transfer
    // ========================================================================

    task receive_output;

        input integer index;

        begin

            src_ready = 1'b1;

            while (!tx_two_done)
                @(posedge clk);

            #1;

            output_chunks[index] =
                final_data_out;

            src_ready = 1'b0;

            @(posedge clk);

        end

    endtask


    // ========================================================================
    // Self-check one approximate matrix result
    //
    // IMPORTANT:
    //
    // exact_value:
    //     Exact mathematical matrix multiplication result.
    //
    // actual_value:
    //     Result produced by the approximate MAC.
    //
    // The test does NOT require actual == exact.
    //
    // It requires:
    //
    // relative error <= MAX_ERROR_PERCENT
    //
    // ========================================================================

    task check_approx_element;

        input integer row;
        input integer col;
        input real exact_value;

        integer index;

        reg [31:0] actual_bits;

        real actual_value;

        real signed_error;
        real abs_error;
        real percent_error;

        begin

            index =
                row * 4 + col;

            actual_bits =
                get_output_element(index);

            actual_value =
                q16_16_to_real(actual_bits);


            // ---------------------------------------------------------------
            // Calculate approximation error
            // ---------------------------------------------------------------

            signed_error =
                actual_value - exact_value;


            if (signed_error < 0.0)

                abs_error =
                    -signed_error;

            else

                abs_error =
                    signed_error;


            if (exact_value != 0.0)

                percent_error =
                    (abs_error / exact_value) * 100.0;

            else begin

                if (abs_error == 0.0)
                    percent_error = 0.0;
                else
                    percent_error = 100.0;

            end


            // ---------------------------------------------------------------
            // Display result
            // ---------------------------------------------------------------

            $display(
                "C[%0d][%0d] exact=%8.4f  approx=%8.4f  error=%8.4f  error%%=%6.3f",
                row,
                col,
                exact_value,
                actual_value,
                signed_error,
                percent_error
            );


            // ---------------------------------------------------------------
            // Self-check
            // ---------------------------------------------------------------

            if (percent_error > MAX_ERROR_PERCENT) begin

                $display(
                    "  ERROR: approximation exceeds allowed %0.2f%% limit",
                    MAX_ERROR_PERCENT
                );

                error_count =
                    error_count + 1;

            end

        end

    endtask


    // ========================================================================
    // Check all 16 matrix elements
    // ========================================================================

    task check_output_matrix;

        begin

            error_count = 0;

            $display("");
            $display("==============================================================");
            $display(" APPROXIMATE MAC SELF-CHECK");
            $display(" Allowed relative error = %0.2f%%", MAX_ERROR_PERCENT);
            $display("==============================================================");
            $display("");


            // ----------------------------------------------------------------
            // Row 0
            // ----------------------------------------------------------------

            check_approx_element(
                0, 0, 81.1250
            );

            check_approx_element(
                0, 1, 117.1250
            );

            check_approx_element(
                0, 2, 153.1250
            );

            check_approx_element(
                0, 3, 189.1250
            );


            // ----------------------------------------------------------------
            // Row 1
            // ----------------------------------------------------------------

            check_approx_element(
                1, 0, 96.8750
            );

            check_approx_element(
                1, 1, 140.8750
            );

            check_approx_element(
                1, 2, 184.8750
            );

            check_approx_element(
                1, 3, 228.8750
            );


            // ----------------------------------------------------------------
            // Row 2
            // ----------------------------------------------------------------

            check_approx_element(
                2, 0, 108.6875
            );

            check_approx_element(
                2, 1, 158.6875
            );

            check_approx_element(
                2, 2, 208.6875
            );

            check_approx_element(
                2, 3, 258.6875
            );


            // ----------------------------------------------------------------
            // Row 3
            // ----------------------------------------------------------------

            check_approx_element(
                3, 0, 131.0000
            );

            check_approx_element(
                3, 1, 192.5000
            );

            check_approx_element(
                3, 2, 254.0000
            );

            check_approx_element(
                3, 3, 315.5000
            );


            // ----------------------------------------------------------------
            // Final numerical verification
            // ----------------------------------------------------------------

            $display("");
            $display("==============================================================");


            if (error_count != 0) begin

                $display(
                    " FAIL: %0d OUTPUT(S) EXCEEDED APPROXIMATION LIMIT",
                    error_count
                );

                $display("==============================================================");

                $fatal(
                    1,
                    "Approximate MAC numerical regression failed"
                );

            end

            else begin

                $display(
                    " PASS: ALL 16 OUTPUTS ARE WITHIN EXPECTED APPROXIMATION RANGE"
                );

                $display("==============================================================");

            end

        end

    endtask


    // ========================================================================
    // Main simulation
    // ========================================================================

    integer i;

    initial begin


        // --------------------------------------------------------------------
        // Waveform
        // --------------------------------------------------------------------

        $dumpfile(
            "build/systolic_top_tb.vcd"
        );

        $dumpvars(
            0,
            systolic_top_tb
        );


        // --------------------------------------------------------------------
        // Initial values
        // --------------------------------------------------------------------

        clk       = 1'b0;
        reset     = 1'b1;

        valid_in  = 1'b0;
        data_in   = 128'b0;

        src_valid = 1'b0;
        src_ready = 1'b0;

        error_count = 0;


        // --------------------------------------------------------------------
        // Reset
        // --------------------------------------------------------------------

        #20;

        reset = 1'b0;

        @(posedge clk);


        // --------------------------------------------------------------------
        // Test description
        // --------------------------------------------------------------------

        $display("");
        $display("==============================================================");
        $display(" SYSTOLIC TOP TEST - APPROXIMATE NON-POWER-OF-TWO VALUES");
        $display("==============================================================");

        $display("");

        $display("Matrix A:");

        $display(
            "[ 1.50  3.50  5.50   7.50]"
        );

        $display(
            "[ 2.50  4.50  6.50   8.50]"
        );

        $display(
            "[ 3.25  5.25  7.25   9.25]"
        );

        $display(
            "[ 4.75  6.75  8.75  10.50]"
        );


        $display("");

        $display("Matrix B:");

        $display(
            "[ 2.25  4.25  6.25   8.25]"
        );

        $display(
            "[ 3.50  5.50  7.50   9.50]"
        );

        $display(
            "[ 4.75  6.75  8.75  10.75]"
        );

        $display(
            "[ 5.25  7.25  9.25  11.25]"
        );


        $display("");

        $display(
            "Exact mathematical A x B reference:"
        );

        $display(
            "[ 81.1250  117.1250  153.1250  189.1250]"
        );

        $display(
            "[ 96.8750  140.8750  184.8750  228.8750]"
        );

        $display(
            "[108.6875  158.6875  208.6875  258.6875]"
        );

        $display(
            "[131.0000  192.5000  254.0000  315.5000]"
        );


        $display("");

        $display(
            "Approximate MAC tolerance: %0.2f%%",
            MAX_ERROR_PERCENT
        );

        $display(
            "Individual products remain below the previous Q8.8 saturation limit."
        );

        $display("==============================================================");
        $display("");


        // --------------------------------------------------------------------
        // Start transaction
        // --------------------------------------------------------------------

        valid_in = 1'b1;

        @(posedge clk);

        valid_in = 1'b0;


        // ====================================================================
        // Packet 0
        //
        // A row 0:
        //
        // [1.50 3.50 5.50 7.50]
        //
        // B column 0:
        //
        // [2.25 3.50 4.75 5.25]
        // ====================================================================

        $display(
            "Sending input packet 0"
        );

        send_input_packet(
            {
                FP_1_50,
                FP_3_50,
                FP_5_50,
                FP_7_50,

                FP_2_25,
                FP_3_50,
                FP_4_75,
                FP_5_25
            }
        );

        $display(
            "Input packet 0 accepted."
        );

        @(negedge clk);


        // ====================================================================
        // Packet 1
        //
        // A row 1:
        //
        // [2.50 4.50 6.50 8.50]
        //
        // B column 1:
        //
        // [4.25 5.50 6.75 7.25]
        // ====================================================================

        $display(
            "Sending input packet 1"
        );

        send_input_packet(
            {
                FP_2_50,
                FP_4_50,
                FP_6_50,
                FP_8_50,

                FP_4_25,
                FP_5_50,
                FP_6_75,
                FP_7_25
            }
        );

        $display(
            "Input packet 1 accepted."
        );

        @(negedge clk);


        // ====================================================================
        // Packet 2
        //
        // A row 2:
        //
        // [3.25 5.25 7.25 9.25]
        //
        // B column 2:
        //
        // [6.25 7.50 8.75 9.25]
        // ====================================================================

        $display(
            "Sending input packet 2"
        );

        send_input_packet(
            {
                FP_3_25,
                FP_5_25,
                FP_7_25,
                FP_9_25,

                FP_6_25,
                FP_7_50,
                FP_8_75,
                FP_9_25
            }
        );

        $display(
            "Input packet 2 accepted."
        );

        @(negedge clk);


        // ====================================================================
        // Packet 3
        //
        // A row 3:
        //
        // [4.75 6.75 8.75 10.50]
        //
        // B column 3:
        //
        // [8.25 9.50 10.75 11.25]
        // ====================================================================

        $display(
            "Sending input packet 3"
        );

        send_input_packet(
            {
                FP_4_75,
                FP_6_75,
                FP_8_75,
                FP_10_50,

                FP_8_25,
                FP_9_50,
                FP_10_75,
                FP_11_25
            }
        );

        $display(
            "Input packet 3 accepted."
        );

        @(negedge clk);


        // --------------------------------------------------------------------
        // Inputs complete
        // --------------------------------------------------------------------

        $display("");

        $display(
            "=============================================================="
        );

        $display(
            "All 4 input packets accepted."
        );

        $display(
            "Waiting for systolic computation..."
        );

        $display(
            "=============================================================="
        );

        $display("");


        // --------------------------------------------------------------------
        // Wait for computation
        // --------------------------------------------------------------------

        wait (
            dut.state == dut.LOAD_OUT
        );


        $display("");

        $display(
            "Systolic computation complete."
        );

        $display(
            "Starting output transfers..."
        );

        $display("");


        // --------------------------------------------------------------------
        // Receive complete output matrix
        // --------------------------------------------------------------------

        for (
            i = 0;
            i < 128;
            i = i + 1
        ) begin

            receive_output(i);

        end


        // --------------------------------------------------------------------
        // Display actual approximate output
        // --------------------------------------------------------------------

        print_output_matrix;


        // --------------------------------------------------------------------
        // Self-check approximate numerical behavior
        // --------------------------------------------------------------------

        check_output_matrix;


        // --------------------------------------------------------------------
        // Verify completion signal
        // --------------------------------------------------------------------

        $display("");

        $display(
            "=============================================================="
        );

        $display(
            " ALL 128 OUTPUT TRANSFERS RECEIVED"
        );

        $display(
            "=============================================================="
        );

        $display("");


        @(posedge clk);
        @(posedge clk);


        if (
            done_matrix_mult !== 1'b1
        ) begin

            $fatal(
                1,
                "done_matrix_mult was not asserted"
            );

        end


        $display(
            "PASS: done_matrix_mult asserted."
        );


        $display("");

        $display(
            "=============================================================="
        );

        $display(
            " TEST PASSED"
        );

        $display(
            " All 16 approximate results are within the allowed error range."
        );

        $display(
            "=============================================================="
        );

        $display("");


        #50;

        $finish;

    end

endmodule
`timescale 1ns/1ps

module systolic_top_tb;

    // ------------------------------------------------------------------------
    // DUT signals
    // ------------------------------------------------------------------------

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


    // ------------------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------------------

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


    // ------------------------------------------------------------------------
    // Clock
    // ------------------------------------------------------------------------

    always #5 clk = ~clk;


    // ------------------------------------------------------------------------
    // FP16 conversion
    //
    // Values used:
    // 0, 1, 2, 4, 8, 16
    // ------------------------------------------------------------------------

    function automatic [15:0] fp16(input integer val);

        begin

            case (val)

                0 : fp16 = 16'h0000;   // 0.0
                1 : fp16 = 16'h3C00;   // 1.0
                2 : fp16 = 16'h4000;   // 2.0
                4 : fp16 = 16'h4400;   // 4.0
                8 : fp16 = 16'h4800;   // 8.0
                16: fp16 = 16'h4C00;   // 16.0

                default: fp16 = 16'h0000;

            endcase

        end

    endfunction


    // ------------------------------------------------------------------------
    // Output storage
    //
    // 128 transfers x 4 bits = 512 bits
    //
    // 8 transfers = one 32-bit Q16.16 matrix element
    // ------------------------------------------------------------------------

    reg [3:0] output_chunks [0:127];


    // ------------------------------------------------------------------------
    // Reconstruct one 32-bit Q16.16 value
    // ------------------------------------------------------------------------

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


    // ------------------------------------------------------------------------
    // Print Q16.16 value
    // ------------------------------------------------------------------------

    task print_q16_16;

        input [31:0] value;

        reg [15:0] integer_part;
        reg [15:0] fractional_part;

        real decimal_value;

        begin

            integer_part    = value[31:16];
            fractional_part = value[15:0];

            decimal_value =
                integer_part +
                (fractional_part / 65536.0);

            $write("%0.4f", decimal_value);

        end

    endtask


    // ------------------------------------------------------------------------
    // Print complete 4x4 matrix
    // ------------------------------------------------------------------------

    task print_output_matrix;

        integer row;
        integer col;
        integer element_index;

        reg [31:0] element;

        begin

            $display("");
            $display("==============================================");
            $display(" SYSTOLIC OUTPUT MATRIX");
            $display(" Format: Q16.16");
            $display(" [31:16] = Integer");
            $display(" [15:0]  = Fraction");
            $display("==============================================");
            $display("");

            for (row = 0; row < 4; row = row + 1) begin

                $write("[ ");

                for (col = 0; col < 4; col = col + 1) begin

                    element_index = row * 4 + col;

                    element =
                        get_output_element(element_index);

                    print_q16_16(element);

                    if (col != 3)
                        $write("  ");

                end

                $display(" ]");

            end

            $display("");

        end

    endtask


    // ------------------------------------------------------------------------
    // Send one 128-bit input packet
    // ------------------------------------------------------------------------

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


    // ------------------------------------------------------------------------
    // Receive one output nibble
    // ------------------------------------------------------------------------

    task receive_output;

        input integer index;

        begin

            src_ready = 1'b1;

            while (!tx_two_done)
                @(posedge clk);

            #1;

            output_chunks[index] = final_data_out;

            $display(
                "%0t: Output[%0d] = %h   tx_two_done=%b",
                $time,
                index,
                final_data_out,
                tx_two_done
            );

            src_ready = 1'b0;

            @(posedge clk);

        end

    endtask


    // ------------------------------------------------------------------------
    // Check one matrix element
    //
    // expected_integer is converted to Q16.16:
    //
    // expected_integer << 16
    // ------------------------------------------------------------------------

    task check_element;

        input integer row;
        input integer col;
        input integer expected_integer;

        integer index;

        reg [31:0] actual;
        reg [31:0] expected_q16;

        begin

            index = row * 4 + col;

            actual =
                get_output_element(index);

            expected_q16 =
                expected_integer << 16;

            if (actual !== expected_q16) begin

                $display(
                    "FAIL: C[%0d][%0d] expected %0d.0000 (0x%08h), got 0x%08h",
                    row,
                    col,
                    expected_integer,
                    expected_q16,
                    actual
                );

                errors = errors + 1;

            end
            else begin

                $display(
                    "PASS: C[%0d][%0d] = %0d.0000",
                    row,
                    col,
                    expected_integer
                );

            end

        end

    endtask


    // ------------------------------------------------------------------------
    // Check complete expected matrix
    //
    // Expected:
    //
    // [128 304 272 196]
    // [196 128 304 272]
    // [272 196 128 304]
    // [304 272 196 128]
    // ------------------------------------------------------------------------

    task check_output_matrix;

        begin

            errors = 0;

            $display("");
            $display("==============================================");
            $display(" CHECKING OUTPUT MATRIX");
            $display("==============================================");


            // Row 0

            check_element(0, 0, 128);
            check_element(0, 1, 304);
            check_element(0, 2, 272);
            check_element(0, 3, 196);


            // Row 1

            check_element(1, 0, 196);
            check_element(1, 1, 128);
            check_element(1, 2, 304);
            check_element(1, 3, 272);


            // Row 2

            check_element(2, 0, 272);
            check_element(2, 1, 196);
            check_element(2, 2, 128);
            check_element(2, 3, 304);


            // Row 3

            check_element(3, 0, 304);
            check_element(3, 1, 272);
            check_element(3, 2, 196);
            check_element(3, 3, 128);


            $display("");

            if (errors == 0) begin

                $display("==============================================");
                $display(" PASS: ALL 16 MATRIX ELEMENTS ARE CORRECT");
                $display("==============================================");

            end
            else begin

                $display("==============================================");

                $display(
                    " FAIL: %0d MATRIX ELEMENT(S) INCORRECT",
                    errors
                );

                $display("==============================================");

            end

        end

    endtask


    // ------------------------------------------------------------------------
    // Main simulation
    // ------------------------------------------------------------------------

    integer i;
    integer errors;


    initial begin


        // --------------------------------------------------------------------
        // Waveform
        // --------------------------------------------------------------------

        $dumpfile("build/systolic_top_tb.vcd");
        $dumpvars(0, systolic_top_tb);


        // --------------------------------------------------------------------
        // Initial values
        // --------------------------------------------------------------------

        clk       = 1'b0;
        reset     = 1'b1;

        valid_in  = 1'b0;
        data_in   = 128'b0;

        src_valid = 1'b0;
        src_ready = 1'b0;

        errors = 0;


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
        $display("==============================================");
        $display(" SYSTOLIC TOP TEST - LARGE VALUES");
        $display("==============================================");

        $display("");

        $display("Matrix A:");

        $display("[ 2  4  8 16]");
        $display("[ 4  8 16  2]");
        $display("[ 8 16  2  4]");
        $display("[16  2  4  8]");

        $display("");

        $display("Matrix B:");

        $display("[16  8  4  2]");
        $display("[ 8  4  2 16]");
        $display("[ 4  2 16  8]");
        $display("[ 2 16  8  4]");

        $display("");

        $display("Expected A x B:");

        $display("[128 304 272 196]");
        $display("[196 128 304 272]");
        $display("[272 196 128 304]");
        $display("[304 272 196 128]");

        $display("");

        $display("Input width       = 128 bits");
        $display("Internal result   = 512 bits");
        $display("Output width      = 4 bits");
        $display("Output transfers  = 128");
        $display("Matrix element    = 32-bit Q16.16");

        $display("==============================================");
        $display("");


        // --------------------------------------------------------------------
        // Start matrix multiplication
        // --------------------------------------------------------------------

        valid_in = 1'b1;

        @(posedge clk);

        valid_in = 1'b0;


        // --------------------------------------------------------------------
        // Packet 0
        //
        // A row 0:
        //
        // [2 4 8 16]
        //
        // B column 0:
        //
        // [16 8 4 2]
        // --------------------------------------------------------------------

        $display("Sending input packet 0");

        send_input_packet(
            {
                fp16(2),
                fp16(4),
                fp16(8),
                fp16(16),

                fp16(16),
                fp16(8),
                fp16(4),
                fp16(2)
            }
        );

        $display(
            "Input packet 0 accepted."
        );

        @(negedge clk);


        // --------------------------------------------------------------------
        // Packet 1
        //
        // A row 1:
        //
        // [4 8 16 2]
        //
        // B column 1:
        //
        // [8 4 2 16]
        // --------------------------------------------------------------------

        $display("Sending input packet 1");

        send_input_packet(
            {
                fp16(4),
                fp16(8),
                fp16(16),
                fp16(2),

                fp16(8),
                fp16(4),
                fp16(2),
                fp16(16)
            }
        );

        $display(
            "Input packet 1 accepted."
        );

        @(negedge clk);


        // --------------------------------------------------------------------
        // Packet 2
        //
        // A row 2:
        //
        // [8 16 2 4]
        //
        // B column 2:
        //
        // [4 2 16 8]
        // --------------------------------------------------------------------

        $display("Sending input packet 2");

        send_input_packet(
            {
                fp16(8),
                fp16(16),
                fp16(2),
                fp16(4),

                fp16(4),
                fp16(2),
                fp16(16),
                fp16(8)
            }
        );

        $display(
            "Input packet 2 accepted."
        );

        @(negedge clk);


        // --------------------------------------------------------------------
        // Packet 3
        //
        // A row 3:
        //
        // [16 2 4 8]
        //
        // B column 3:
        //
        // [2 16 8 4]
        // --------------------------------------------------------------------

        $display("Sending input packet 3");

        send_input_packet(
            {
                fp16(16),
                fp16(2),
                fp16(4),
                fp16(8),

                fp16(2),
                fp16(16),
                fp16(8),
                fp16(4)
            }
        );

        $display(
            "Input packet 3 accepted."
        );

        @(negedge clk);


        // --------------------------------------------------------------------
        // All input packets loaded
        // --------------------------------------------------------------------

        $display("");
        $display("==============================================");

        $display(
            "All 4 input packets accepted."
        );

        $display(
            "Waiting for systolic computation..."
        );

        $display("==============================================");
        $display("");


        // --------------------------------------------------------------------
        // Wait until matrix output is ready
        // --------------------------------------------------------------------

        wait (dut.state == dut.LOAD_OUT);


        $display("");

        $display(
            "Systolic computation complete."
        );

        $display(
            "Starting output transfers..."
        );

        $display("");


        // --------------------------------------------------------------------
        // Receive all 128 4-bit transfers
        // --------------------------------------------------------------------

        for (i = 0; i < 128; i = i + 1) begin

            receive_output(i);

        end


        // --------------------------------------------------------------------
        // Print reconstructed matrix
        // --------------------------------------------------------------------

        print_output_matrix;


        // --------------------------------------------------------------------
        // Verify all 16 values
        // --------------------------------------------------------------------

        check_output_matrix;


        // --------------------------------------------------------------------
        // Final status
        // --------------------------------------------------------------------

        $display("");

        $display("==============================================");

        $display(
            " ALL 128 OUTPUT TRANSFERS RECEIVED"
        );

        $display("==============================================");

        $display("");


        @(posedge clk);
        @(posedge clk);


        if (done_matrix_mult !== 1'b1) begin

            $display(
                "WARNING: done_matrix_mult not observed yet."
            );

        end
        else begin

            $display(
                "PASS: done_matrix_mult asserted."
            );

        end


        $display("");


        if (errors == 0) begin

            $display(
                "FINAL RESULT: TEST PASSED"
            );

        end
        else begin

            $display(
                "FINAL RESULT: TEST FAILED"
            );

        end


        $display("");

        $display(
            "SYSTOLIC TOP TEST COMPLETED."
        );

        $display("");


        #50;

        $finish;

    end

endmodule
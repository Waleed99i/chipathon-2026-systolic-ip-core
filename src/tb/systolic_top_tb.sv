`timescale 1ns/1ps

module systolic_top_tb;

    // ------------------------------------------------------------------------
    // DUT signals
    // ------------------------------------------------------------------------

    reg clk;
    reg reset;

    reg valid_in;
    reg [127:0] data_in;

    reg src_valid;
    reg src_ready;

    // NEW: 4-bit output
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
    // Integer 1..20 -> IEEE-754 half precision
    // ------------------------------------------------------------------------

    function automatic [15:0] fp16(input integer val);

        case (val)

            1:  fp16 = 16'h3C00;
            2:  fp16 = 16'h4000;
            3:  fp16 = 16'h4200;
            4:  fp16 = 16'h4400;

            5:  fp16 = 16'h4500;
            6:  fp16 = 16'h4600;
            7:  fp16 = 16'h4700;
            8:  fp16 = 16'h4800;

            9:  fp16 = 16'h4880;
            10: fp16 = 16'h4900;
            11: fp16 = 16'h4980;
            12: fp16 = 16'h4A00;

            13: fp16 = 16'h4A80;
            14: fp16 = 16'h4B00;
            15: fp16 = 16'h4B80;
            16: fp16 = 16'h4C00;

            17: fp16 = 16'h4C40;
            18: fp16 = 16'h4C80;
            19: fp16 = 16'h4CC0;
            20: fp16 = 16'h4D00;

            default: fp16 = 16'h0000;

        endcase

    endfunction


    // ------------------------------------------------------------------------
    // Send one 128-bit input packet
    // ------------------------------------------------------------------------

    task send_input_packet;

        input [127:0] packet;

        begin

            data_in   = packet;
            src_valid = 1'b1;

            // Wait until the systolic input datapath accepts it
            while (!tx_one_done)
                @(posedge clk);

            @(posedge clk);

            src_valid = 1'b0;

        end

    endtask


    // ------------------------------------------------------------------------
    // Receive one 4-bit output transfer
    // ------------------------------------------------------------------------

    task receive_output;

        input integer index;

        begin

            src_ready = 1'b1;

            // Wait for a valid output transfer
            while (!tx_two_done)
                @(posedge clk);

            #1;

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
    // Main simulation
    // ------------------------------------------------------------------------

    integer i;

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


        // --------------------------------------------------------------------
        // Reset
        // --------------------------------------------------------------------

        #20;

        reset = 1'b0;

        @(posedge clk);


        // --------------------------------------------------------------------
        // Monitor internal state
        // --------------------------------------------------------------------

    


        // --------------------------------------------------------------------
        // Start transaction
        // --------------------------------------------------------------------

        $display("");
        $display("==============================================");
        $display(" SYSTOLIC TOP TEST");
        $display("==============================================");
        $display("Input width       = 128 bits");
        $display("Internal result   = 512 bits");
        $display("Output width      = 4 bits");
        $display("Output transfers  = 128");
        $display("==============================================");
        $display("");


        valid_in = 1'b1;

        @(posedge clk);

        valid_in = 1'b0;


        // --------------------------------------------------------------------
        // Send four 128-bit input packets
        //
        // Each packet:
        //
        //   4 FP16 values = one row
        //   4 FP16 values = one column
        //
        // Total = 8 × 16 = 128 bits
        // --------------------------------------------------------------------

        for (i = 0; i < 4; i = i + 1) begin

            $display("");
            $display(
                "Sending input packet %0d",
                i
            );

            send_input_packet(
                {
                    fp16(i*4+1),
                    fp16(i*4+2),
                    fp16(i*4+3),
                    fp16(i*4+4),

                    fp16(i*4+5),
                    fp16(i*4+6),
                    fp16(i*4+7),
                    fp16(i*4+8)
                }
            );

            $display(
                "Input packet %0d accepted.",
                i
            );

            @(negedge clk);

        end


        $display("");
        $display("All 4 input packets accepted.");
        $display("Waiting for systolic computation...");
        $display("");


        // --------------------------------------------------------------------
        // Wait until matrix multiplication is complete
        //
        // The output datapath will then start transferring
        // the 512-bit result as 128 × 4-bit chunks.
        // --------------------------------------------------------------------

        wait (dut.state == dut.LOAD_OUT);

        $display("");
        $display("Systolic computation complete.");
        $display("Starting output transfers...");
        $display("");


        // --------------------------------------------------------------------
        // Receive 128 × 4-bit output transfers
        // --------------------------------------------------------------------

        for (i = 0; i < 128; i = i + 1) begin

            receive_output(i);

        end


        // --------------------------------------------------------------------
        // Final status
        // --------------------------------------------------------------------

        $display("");
        $display("==============================================");
        $display(" ALL 128 OUTPUT TRANSFERS RECEIVED");
        $display("==============================================");
        $display("");

@(posedge clk);
@(posedge clk);

if (done_matrix_mult !== 1'b1) begin
    $display("WARNING: done_matrix_mult not observed yet.");
end
else begin
    $display("PASS: done_matrix_mult asserted.");
end


        $display("");
        $display("SYSTOLIC TOP TEST COMPLETED.");
        $display("");


        #50;

        $finish;

    end

endmodule

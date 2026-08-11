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
// Only values 0 and 1 are required for this test.
// ------------------------------------------------------------------------

function automatic [15:0] fp16(input integer val);

    case (val)

        0: fp16 = 16'h0000;   // 0.0
        1: fp16 = 16'h3C00;   // 1.0

        default: fp16 = 16'h0000;

    endcase

endfunction


// ------------------------------------------------------------------------
// Output storage
//
// 128 transfers × 4 bits = 512 bits
//
// 8 transfers = one 32-bit Q16.16 matrix element
// ------------------------------------------------------------------------

reg [3:0] output_chunks [0:127];


// ------------------------------------------------------------------------
// Reconstruct one 32-bit Q16.16 value
//
// 8 × 4-bit chunks:
//
//   Output[0] ... Output[3] = [31:16]
//   Output[4] ... Output[7] = [15:0]
//
// Example:
//
//   0 0 0 2 0 0 0 0
//
//   => 32'h00020000
//   => Q16.16 = 2.0
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
// Print one Q16.16 value
//
// [31:16] = integer part
// [15:0]  = fractional part
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
// Print complete 4×4 output matrix
//
// Matrix is reconstructed from the actual 128 received chunks.
// Nothing is hard-coded.
// ------------------------------------------------------------------------

task print_output_matrix;

    integer row;
    integer col;
    integer element_index;

    reg [31:0] element;

    begin

        $display("");
        $display("==============================================");
        $display(" APPROXIMATE MAC OUTPUT MATRIX");
        $display(" Format: Q16.16");
        $display(" [31:16] = Integer");
        $display(" [15:0]  = Fraction");
        $display("==============================================");
        $display("");

        for (row = 0; row < 4; row = row + 1) begin

            $write("[ ");

            for (col = 0; col < 4; col = col + 1) begin

                element_index = row * 4 + col;

                element = get_output_element(element_index);

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
// Receive one 4-bit output transfer
// ------------------------------------------------------------------------

task receive_output;

    input integer index;

    begin

        src_ready = 1'b1;

        while (!tx_two_done)
            @(posedge clk);

        #1;

        // Store actual received chunk
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
    // Test description
    // --------------------------------------------------------------------

    // $display("");
    // $display("==============================================");
    // $display(" SYSTOLIC TOP TEST");
    // $display("==============================================");

    // $display("Matrix A:");
    // $display("[1 0 1 0]");
    // $display("[0 1 0 1]");
    // $display("[1 0 1 0]");
    // $display("[0 1 0 1]");

    // $display("");

    // $display("Matrix B:");
    // $display("[1 0 1 0]");
    // $display("[0 1 0 1]");
    // $display("[1 0 1 0]");
    // $display("[0 1 0 1]");

    // $display("");

    // $display("Expected A x B:");
    // $display("[2 0 2 0]");
    // $display("[0 2 0 2]");
    // $display("[2 0 2 0]");
    // $display("[0 2 0 2]");

    $display("");

    $display("Input width       = 128 bits");
    $display("Internal result   = 512 bits");
    $display("Output width      = 4 bits");
    $display("Output transfers  = 128");
    $display("Matrix element    = 32-bit Q16.16");

    $display("==============================================");
    $display("");


    // --------------------------------------------------------------------
    // Start transaction
    // --------------------------------------------------------------------

    valid_in = 1'b1;

    @(posedge clk);

    valid_in = 1'b0;


    // --------------------------------------------------------------------
    // Packet 0
    //
    // A row 0 = [1 0 1 0]
    // B col 0 = [1 0 1 0]
    // --------------------------------------------------------------------

    $display("Sending input packet 0");

    send_input_packet(
        {
            fp16(1), fp16(0), fp16(1), fp16(0),
            fp16(1), fp16(0), fp16(1), fp16(0)
        }
    );

    $display("Input packet 0 accepted.");

    @(negedge clk);


    // --------------------------------------------------------------------
    // Packet 1
    //
    // A row 1 = [0 1 0 1]
    // B col 1 = [0 1 0 1]
    // --------------------------------------------------------------------

    $display("Sending input packet 1");

    send_input_packet(
        {
            fp16(0), fp16(1), fp16(0), fp16(1),
            fp16(0), fp16(1), fp16(0), fp16(1)
        }
    );

    $display("Input packet 1 accepted.");

    @(negedge clk);


    // --------------------------------------------------------------------
    // Packet 2
    //
    // A row 2 = [1 0 1 0]
    // B col 2 = [1 0 1 0]
    // --------------------------------------------------------------------

    $display("Sending input packet 2");

    send_input_packet(
        {
            fp16(1), fp16(0), fp16(1), fp16(0),
            fp16(1), fp16(0), fp16(1), fp16(0)
        }
    );

    $display("Input packet 2 accepted.");

    @(negedge clk);


    // --------------------------------------------------------------------
    // Packet 3
    //
    // A row 3 = [0 1 0 1]
    // B col 3 = [0 1 0 1]
    // --------------------------------------------------------------------

    $display("Sending input packet 3");

    send_input_packet(
        {
            fp16(0), fp16(1), fp16(0), fp16(1),
            fp16(0), fp16(1), fp16(0), fp16(1)
        }
    );

    $display("Input packet 3 accepted.");

    @(negedge clk);


    // --------------------------------------------------------------------
    // All inputs received
    // --------------------------------------------------------------------

    $display("");
    $display("==============================================");
    $display("All 4 input packets accepted.");
    $display("Waiting for systolic computation...");
    $display("==============================================");
    $display("");


    // --------------------------------------------------------------------
    // Wait for computation
    // --------------------------------------------------------------------

    wait (dut.state == dut.LOAD_OUT);

    $display("");
    $display("Systolic computation complete.");
    $display("Starting output transfers...");
    $display("");


    // --------------------------------------------------------------------
    // Receive all 128 output transfers
    // --------------------------------------------------------------------

    for (i = 0; i < 128; i = i + 1) begin

        receive_output(i);

    end


    // --------------------------------------------------------------------
    // Print reconstructed output matrix
    // --------------------------------------------------------------------

    print_output_matrix;


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

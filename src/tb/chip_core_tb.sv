`timescale 1ns/1ps
`default_nettype none

module chip_core_tb;

    // ============================================================
    // PARAMETERS
    // ============================================================

    localparam NUM_INPUT_PADS  = 8;
    localparam NUM_BIDIR_PADS = 4;
    localparam NUM_ANALOG_PADS = 0;

    // ============================================================
    // CLOCK / RESET
    // ============================================================

    reg clk;
    reg rst_n;

    // ============================================================
    // INPUT PADS
    // ============================================================

    reg [NUM_INPUT_PADS-1:0] input_in;

    // ============================================================
    // BIDIR PADS
    // ============================================================

    wire [NUM_BIDIR_PADS-1:0] bidir_in;
    wire [NUM_BIDIR_PADS-1:0] bidir_out;

    // ============================================================
    // DUT
    // ============================================================

    // Pad-control terminals (CS/SL/IE/OE/PU/PD/PDRV0/PDRV1,
    // rst_n_PU/PD, clk_PU/PD) are intentionally left unconnected —
    // not read or checked anywhere in this testbench.
    chip_core dut (

        .clk   (clk),
        .rst_n (rst_n),

        .input_in_0 (input_in[0]),
        .input_in_1 (input_in[1]),
        .input_in_2 (input_in[2]),
        .input_in_3 (input_in[3]),
        .input_in_4 (input_in[4]),
        .input_in_5 (input_in[5]),
        .input_in_6 (input_in[6]),
        .input_in_7 (input_in[7]),

        .output_out_0_IN  (bidir_in[0]),
        .output_out_0_OUT (bidir_out[0]),
        .output_out_1_IN  (bidir_in[1]),
        .output_out_1_OUT (bidir_out[1]),
        .output_out_2_IN  (bidir_in[2]),
        .output_out_2_OUT (bidir_out[2]),
        .output_out_3_IN  (bidir_in[3]),
        .output_out_3_OUT (bidir_out[3])
    );

    assign bidir_in = 4'b0000;

    // ============================================================
    // CLOCK
    // ============================================================

    always #5 clk = ~clk;

    // ============================================================
    // FP16 ENCODING
    // ============================================================

    function automatic [15:0] fp16;

        input integer value;

        begin

            case (value)

                0: fp16 = 16'h0000;
                1: fp16 = 16'h3C00;
                2: fp16 = 16'h4000;

                default:
                    fp16 = 16'h0000;

            endcase

        end

    endfunction

    // ============================================================
    // OUTPUT STORAGE
    //
    // 128 output transfers
    // Each transfer = 4 bits
    //
    // Total:
    //
    // 128 x 4 = 512 bits
    //
    // 16 matrix elements x 32 bits = 512 bits
    //
    // Therefore:
    //
    // 8 output chunks = 1 matrix element
    // ============================================================

    reg [3:0] output_chunks [0:127];

    // ============================================================
    // OUTPUT MONITOR COUNTER
    // ============================================================

    integer output_count;

    // ============================================================
    // RECONSTRUCT ONE 32-BIT Q16.16 ELEMENT
    //
    // For element N:
    //
    // chunk N*8 + 0 ... N*8 + 3 = bits [31:16]
    // chunk N*8 + 4 ... N*8 + 7 = bits [15:0]
    //
    // Example:
    //
    // Output chunks:
    //
    // 0 0 0 1 0 0 0 0
    //
    // gives:
    //
    // 32'h00010000
    //
    // Q16.16 = 1.0
    // ============================================================

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

    // ============================================================
    // PRINT Q16.16 VALUE
    //
    // [31:16] = integer part
    // [15:0]  = fractional part
    // ============================================================

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

    // ============================================================
    // PRINT RESULTANT 4x4 MATRIX
    // ============================================================

    task print_result_matrix;

        integer row;
        integer col;
        integer element_index;

        reg [31:0] element;

        begin

            $display("");
            $display("==============================================");
            $display(" CHIP CORE RESULTANT MATRIX");
            $display("==============================================");
            $display("");
            $display("Format: Q16.16");
            $display("[31:16] = Integer");
            $display("[15:0]  = Fraction");
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

            $display("==============================================");
            $display("");

        end

    endtask

    // ============================================================
    // SEND ONE BYTE
    // ============================================================

    task send_byte;

        input [7:0] value;

        begin

            @(negedge clk);

            input_in = value;

            @(posedge clk);

        end

    endtask

    // ============================================================
    // SEND ONE 128-BIT PACKET
    // ============================================================

    task send_packet;

        input integer a0;
        input integer a1;
        input integer a2;
        input integer a3;

        input integer b0;
        input integer b1;
        input integer b2;
        input integer b3;

        reg [127:0] packet;

        begin

            packet = {
                fp16(a0),
                fp16(a1),
                fp16(a2),
                fp16(a3),

                fp16(b0),
                fp16(b1),
                fp16(b2),
                fp16(b3)
            };

            $display("");
            $display("----------------------------------------------");
            $display("Sending 128-bit packet");
            $display("Packet = %h", packet);
            $display("----------------------------------------------");

            // --------------------------------------------------------
            // MSB FIRST
            // --------------------------------------------------------

            send_byte(packet[127:120]);
            send_byte(packet[119:112]);

            send_byte(packet[111:104]);
            send_byte(packet[103:96]);

            send_byte(packet[95:88]);
            send_byte(packet[87:80]);

            send_byte(packet[79:72]);
            send_byte(packet[71:64]);

            send_byte(packet[63:56]);
            send_byte(packet[55:48]);

            send_byte(packet[47:40]);
            send_byte(packet[39:32]);

            send_byte(packet[31:24]);
            send_byte(packet[23:16]);

            send_byte(packet[15:8]);
            send_byte(packet[7:0]);

            // --------------------------------------------------------
            // Wait until packet is accepted
            // --------------------------------------------------------

            wait (dut.chip_core_internal_i.systolic_tx_one_done);

            @(posedge clk);

            $display(
                "%0t : PACKET ACCEPTED",
                $time
            );

        end

    endtask

    // ============================================================
    // OUTPUT MONITOR
    //
    // Store the actual 4-bit output chunks.
    // ============================================================

    always @(posedge clk) begin

        // --------------------------------------------------------
        // Capture only the first 128 output transfers.
        // --------------------------------------------------------

        if (dut.chip_core_internal_i.systolic_tx_two_done &&
            output_count < 128) begin

            output_chunks[output_count] = bidir_out;

            $display(
                "%0t : TX_TWO_DONE | OUTPUT[%0d] = %h",
                $time,
                output_count,
                bidir_out
            );

            output_count = output_count + 1;

        end

        // --------------------------------------------------------
        // Systolic done
        // --------------------------------------------------------

        if (dut.chip_core_internal_i.systolic_done) begin

            $display(
                "%0t : SYSTOLIC_DONE",
                $time
            );

        end

    end

    // ============================================================
    // MAIN TEST
    // ============================================================

    initial begin

        // --------------------------------------------------------
        // Waveform
        // --------------------------------------------------------

        $dumpfile("build/chip_core_tb.vcd");
        $dumpvars(0, chip_core_tb);

        // --------------------------------------------------------
        // Initial values
        // --------------------------------------------------------

        clk = 1'b0;
        rst_n = 1'b0;

        input_in = 8'h00;

        output_count = 0;

        // Initialize output storage
        for (integer k = 0; k < 128; k = k + 1) begin
            output_chunks[k] = 4'b0000;
        end

        // --------------------------------------------------------
        // RESET
        // --------------------------------------------------------

        $display("");
        $display("Resetting DUT...");
        $display("");

        #30;

        rst_n = 1'b1;

        @(posedge clk);

        // ========================================================
        // TEST
        // ========================================================

        $display("==============================================");
        $display(" CHIP CORE TEST");
        $display("==============================================");

        $display("");

        $display("Matrix A:");
        $display("[1 0 0 0]");
        $display("[0 1 0 0]");
        $display("[0 0 1 0]");
        $display("[0 0 0 1]");

        $display("");

        $display("Matrix B:");
        $display("[1 0 0 0]");
        $display("[0 1 0 0]");
        $display("[0 0 1 0]");
        $display("[0 0 0 1]");

        $display("");

        $display("Expected A x B:");
        $display("[1 0 0 0]");
        $display("[0 1 0 0]");
        $display("[0 0 1 0]");
        $display("[0 0 0 1]");

        $display("");
        $display("==============================================");

        // ========================================================
        // PACKET 0
        //
        // A row 0 = [1 0 0 0]
        // B col 0 = [1 0 0 0]
        // ========================================================

        send_packet(
            1, 0, 0, 0,
            1, 0, 0, 0
        );

        // ========================================================
        // PACKET 1
        //
        // A row 1 = [0 1 0 0]
        // B col 1 = [0 1 0 0]
        // ========================================================

        send_packet(
            0, 1, 0, 0,
            0, 1, 0, 0
        );

        // ========================================================
        // PACKET 2
        //
        // A row 2 = [0 0 1 0]
        // B col 2 = [0 0 1 0]
        // ========================================================

        send_packet(
            0, 0, 1, 0,
            0, 0, 1, 0
        );

        // ========================================================
        // PACKET 3
        //
        // A row 3 = [0 0 0 1]
        // B col 3 = [0 0 0 1]
        // ========================================================

        send_packet(
            0, 0, 0, 1,
            0, 0, 0, 1
        );

        // ========================================================
        // ALL INPUTS SENT
        // ========================================================

        $display("");
        $display("==============================================");
        $display(" ALL 4 PACKETS SENT");
        $display(" Waiting for systolic computation...");
        $display("==============================================");
        $display("");

        // --------------------------------------------------------
        // Wait for matrix multiplication
        // --------------------------------------------------------

        wait (dut.chip_core_internal_i.systolic_done);

        $display("");
        $display("==============================================");
        $display(" MATRIX MULTIPLICATION DONE");
        $display("==============================================");
        $display("");

        // --------------------------------------------------------
        // Wait until all 128 output transfers are captured.
        //
        // This is better than an arbitrary #10000 because we
        // specifically wait for the complete 512-bit result.
        // --------------------------------------------------------

        wait (output_count == 128);

        // Small delay so final output chunk is settled
        #1;

        // --------------------------------------------------------
        // Print resultant matrix
        // --------------------------------------------------------

        print_result_matrix;

        // --------------------------------------------------------
        // Final status
        // --------------------------------------------------------

        $display("==============================================");
        $display(" TEST COMPLETED");
        $display(" Output transfers observed = %0d",
                 output_count);
        $display("==============================================");
        $display("");

        $finish;

    end

endmodule

`default_nettype wire
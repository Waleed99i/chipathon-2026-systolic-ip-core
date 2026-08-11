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

    wire [NUM_INPUT_PADS-1:0] input_pu;
    wire [NUM_INPUT_PADS-1:0] input_pd;

    // ============================================================
    // BIDIR PADS
    // ============================================================

    wire [NUM_BIDIR_PADS-1:0] bidir_in;

    wire [NUM_BIDIR_PADS-1:0] bidir_out;
    wire [NUM_BIDIR_PADS-1:0] bidir_oe;
    wire [NUM_BIDIR_PADS-1:0] bidir_cs;
    wire [NUM_BIDIR_PADS-1:0] bidir_sl;
    wire [NUM_BIDIR_PADS-1:0] bidir_ie;
    wire [NUM_BIDIR_PADS-1:0] bidir_pu;
    wire [NUM_BIDIR_PADS-1:0] bidir_pd;

    // ============================================================
    // ANALOG
    // ============================================================

    wire [NUM_ANALOG_PADS-1:0] analog;

    // ============================================================
    // DUT
    // ============================================================

    chip_core #(
        .NUM_INPUT_PADS  (NUM_INPUT_PADS),
        .NUM_BIDIR_PADS  (NUM_BIDIR_PADS),
        .NUM_ANALOG_PADS (NUM_ANALOG_PADS)
    ) dut (

        .clk   (clk),
        .rst_n (rst_n),

        .input_in (input_in),

        .input_pu (input_pu),
        .input_pd (input_pd),

        .bidir_in (bidir_in),

        .bidir_out (bidir_out),
        .bidir_oe  (bidir_oe),
        .bidir_cs  (bidir_cs),
        .bidir_sl  (bidir_sl),
        .bidir_ie  (bidir_ie),
        .bidir_pu  (bidir_pu),
        .bidir_pd  (bidir_pd),

        .analog (analog)
    );

    assign bidir_in = 4'b0000;

    // ============================================================
    // CLOCK
    // ============================================================

    always #5 clk = ~clk;

    // ============================================================
    // FP16 ENCODING
    //
    // 0 = 0000
    // 1 = 3C00
    // 2 = 4000
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
    //
    // 4 A values + 4 B values
    //
    // Each value = FP16 = 16 bits
    //
    // Total = 8 x 16 = 128 bits
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
            // VERY IMPORTANT
            //
            // Do not send packet N+1 until packet N has actually
            // been accepted by systolic.
            // --------------------------------------------------------

            wait (dut.systolic_tx_one_done);

            @(posedge clk);

            $display(
                "%0t : PACKET ACCEPTED",
                $time
            );

        end

    endtask

    // ============================================================
    // OUTPUT MONITOR
    // ============================================================

    integer output_count;

always @(posedge clk) begin

    // Only observe the first 128 real output transfers.
    if (dut.systolic_tx_two_done &&
        output_count < 128) begin

        $display(
            "%0t : TX_TWO_DONE | OUTPUT[%0d] = %h",
            $time,
            output_count,
            bidir_out
        );

        output_count = output_count + 1;

    end

    if (dut.systolic_done) begin

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

        $dumpfile("build/chip_core_tb.vcd");
        $dumpvars(0, chip_core_tb);

        clk = 1'b0;
        rst_n = 1'b0;

        input_in = 8'h00;

        output_count = 0;

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
        $display("Expected:");
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

        wait (dut.systolic_done);

        $display("");
        $display("==============================================");
        $display(" MATRIX MULTIPLICATION DONE");
        $display("==============================================");
        $display("");

        // Give output datapath enough time to finish.
        #10000;

        $display("");
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

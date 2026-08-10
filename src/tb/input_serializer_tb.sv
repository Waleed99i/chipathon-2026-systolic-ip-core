`timescale 1ns/1ps

module input_serializer_tb;

    reg         clk;
    reg         reset;

    reg  [7:0]  data_in;
    reg         valid_in;
    wire        ready_in;

    wire [127:0] data_out;
    wire         valid_out;
    reg          ready_out;

    input_serializer dut (
        .clk       (clk),
        .reset     (reset),

        .data_in   (data_in),
        .valid_in  (valid_in),
        .ready_in  (ready_in),

        .data_out  (data_out),
        .valid_out (valid_out),
        .ready_out (ready_out)
    );

    // 100 MHz clock
    always #5 clk = ~clk;

    initial begin
        $dumpfile("build/input_serializer_tb.vcd");
        $dumpvars(0,input_serializer_tb);

        $display("========================================");
        $display(" Input Serializer Testbench");
        $display(" 8-bit -> 128-bit, MSB-first");
        $display("========================================");

        clk       = 1'b0;
        reset     = 1'b1;
        data_in   = 8'h00;
        valid_in  = 1'b0;
        ready_out = 1'b0;

        // Reset
        #20;
        reset = 1'b0;

        // --------------------------------------------------
        // Send 16 bytes
        // Expected:
        //
        // 123456789ABCDEF01122334455667788
        // --------------------------------------------------

        send_byte(8'h12);
        send_byte(8'h34);
        send_byte(8'h56);
        send_byte(8'h78);
        send_byte(8'h9A);
        send_byte(8'hBC);
        send_byte(8'hDE);
        send_byte(8'hF0);

        send_byte(8'h11);
        send_byte(8'h22);
        send_byte(8'h33);
        send_byte(8'h44);
        send_byte(8'h55);
        send_byte(8'h66);
        send_byte(8'h77);
        send_byte(8'h88);

        // Wait for packet
        wait(valid_out);

        $display("");
        $display("Packet received:");
        $display("data_out = %h", data_out);

        // Check result
        if (data_out === 128'h123456789ABCDEF01122334455667788) begin
            $display("PASS: MSB-first packet assembled correctly.");
        end
        else begin
            $display("FAIL!");
            $display("Expected = 123456789ABCDEF01122334455667788");
            $display("Got      = %h", data_out);
        end

        // --------------------------------------------------
        // Consume packet
        // --------------------------------------------------

        @(posedge clk);
        ready_out = 1'b1;

        @(posedge clk);
        ready_out = 1'b0;

        // --------------------------------------------------
        // Second transaction
        // --------------------------------------------------

        $display("");
        $display("Starting second transaction...");

        send_byte(8'hAA);
        send_byte(8'hBB);
        send_byte(8'hCC);
        send_byte(8'hDD);
        send_byte(8'hEE);
        send_byte(8'hFF);
        send_byte(8'h00);
        send_byte(8'h11);

        send_byte(8'h22);
        send_byte(8'h33);
        send_byte(8'h44);
        send_byte(8'h55);
        send_byte(8'h66);
        send_byte(8'h77);
        send_byte(8'h88);
        send_byte(8'h99);

        wait(valid_out);

        $display("Second packet = %h", data_out);

        if (data_out === 128'hAABBCCDDEEFF00112233445566778899)
            $display("PASS: Second packet correct.");
        else begin
            $display("FAIL: Second packet incorrect.");
            $display("Expected = AABBCCDDEEFF00112233445566778899");
            $display("Got      = %h", data_out);
        end

        @(posedge clk);
        ready_out = 1'b1;

        @(posedge clk);
        ready_out = 1'b0;

        $display("");
        $display("========================================");
        $display(" Testbench finished");
        $display("========================================");

        #20;
        $finish;
    end


    // ------------------------------------------------------
    // Task: send one 8-bit byte
    // ------------------------------------------------------

    task send_byte(input [7:0] byte_value);
        begin

            // Wait until serializer can accept data
            while (!ready_in)
                @(posedge clk);

            @(negedge clk);

            data_in  = byte_value;
            valid_in = 1'b1;

            @(posedge clk);

            // Hold valid for this transfer
            while (!ready_in)
                @(posedge clk);

            @(negedge clk);

            valid_in = 1'b0;

        end
    endtask


    // ------------------------------------------------------
    // Monitor
    // ------------------------------------------------------

    initial begin
        $monitor(
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
    end

endmodule
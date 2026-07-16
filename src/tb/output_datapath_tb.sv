`timescale 1ns/1ps

module output_datapath_tb;

    parameter N = 4;
    parameter PE_OUT_WIDTH = 32;
    parameter OUTPUT_WIDTH = 64;

    localparam TOTAL_WIDTH   = PE_OUT_WIDTH*N*N;
    localparam NUM_TRANSFERS = TOTAL_WIDTH/OUTPUT_WIDTH;

    // DUT signals
    reg clk = 0;
    reg reset = 0;
    reg load_out = 0;
    reg shift = 0;
    reg src_ready = 0;
    reg dest_valid = 0;

    reg  [TOTAL_WIDTH-1:0] systolic_output;

    wire [OUTPUT_WIDTH-1:0] final_data_out;
    //wire sh_count_done;
    wire tx_two_done;

    // Clock generation
    always #5 clk = ~clk;

    // DUT
    output_datapath #(
        .N(N),
        .PE_OUT_WIDTH(PE_OUT_WIDTH),
        .OUTPUT_WIDTH(OUTPUT_WIDTH)
    ) dut (
        .clk(clk),
        .reset(reset),
        .load_out(load_out),
        .shift(shift),
        .src_ready(src_ready),
        .dest_valid(dest_valid),
        .systolic_output(systolic_output),
        .final_data_out(final_data_out),
        //.sh_count_done(sh_count_done),
        .tx_two_done(tx_two_done)
    );

    // Reset DUT
    task reset_dut;
    begin
        reset = 1;
        @(posedge clk);
        reset = 0;
        @(posedge clk);
    end
    endtask

    // Load complete systolic output
    task load_out_data;
        input [TOTAL_WIDTH-1:0] data;
    begin
        systolic_output = data;

        @(posedge clk);
        load_out = 1;

        @(posedge clk);
        load_out = 0;

        @(posedge clk);
    end
    endtask

    // Observe first 64-bit chunk
    task observe_chunk;
        input integer index;
    begin
        $display("\nObserving Chunk %0d", index);

        dest_valid = 1;

        @(posedge clk);

        src_ready = 1;

        @(posedge clk);

        dest_valid = 0;
        src_ready = 0;

        @(posedge clk);

        $display("Time           = %0t", $time);
        $display("Chunk          = %0d", index);
        $display("final_data_out = %h", final_data_out);
        $display("tx_two_done    = %b\n", tx_two_done);
    end
    endtask

    // Shift and transmit next chunk
    task transfer_chunk;
        input integer index;
    begin

        $display("\nTransferring Chunk %0d", index);

        shift = 1;

        @(posedge clk);

        shift = 0;

        @(posedge clk);

        dest_valid = 1;

        @(posedge clk);

        src_ready = 1;

        @(posedge clk);

        dest_valid = 0;
        src_ready = 0;

        @(posedge clk);

        $display("Time           = %0t", $time);
        $display("Chunk          = %0d", index);
        $display("final_data_out = %h", final_data_out);
        $display("tx_two_done    = %b\n", tx_two_done);

    end
    endtask

    integer i;

    initial begin

        $dumpfile("build/output_datapath_tb.vcd");
        $dumpvars(0, output_datapath_tb);

        systolic_output = 512'hDEADBEEFCAFEBABE112233445566778899AABBCCDDEEFF00123456789ABCDEF013579BDFDEADBEEF2468ACE0FEDCBA980FEDCBA9876543211122334455667788;
        // its 
        //systolic_output = {
        //     64'hDEADBEEFCAFEBABE,
        //     64'h1122334455667788,
        //     64'h99AABBCCDDEEFF00,
        //     64'h123456789ABCDEF0,
        //     64'h13579BDFDEADBEEF,
        //     64'h2468ACE0FEDCBA98,
        //     64'h0FEDCBA987654321,
        //     64'h1122334455667788
        // };


        reset_dut();

        load_out_data(systolic_output);

        $display("\nBuffer Contents");
        $display("%h\n", dut.buffer_to_feeder);

        $monitor("T=%0t  feeder_to_rv=%h  count=%0d  ",
                 $time,
                 dut.feeder_to_rv,
                 dut.sh_counter_output_datapath.count);

        @(posedge clk);
        @(posedge clk);

        // First chunk (already at feeder output)
        observe_chunk(0);

        // Remaining chunks
        for(i = 1; i < NUM_TRANSFERS; i = i + 1)
            transfer_chunk(i);


        $display("\nOutput Datapath Test Completed.");

        #50;
        $finish;

    end

endmodule
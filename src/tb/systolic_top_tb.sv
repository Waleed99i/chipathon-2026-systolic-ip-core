`timescale 1ns/1ps

module systolic_top_tb;

    reg clk;
    reg reset;
    reg valid_in;
    reg [127:0] data_in;
    reg src_valid;
    reg src_ready;

    wire [63:0] final_data_out;
    wire done_matrix_mult;
    wire tx_one_done;
    wire tx_two_done;

    systolic dut(
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

    // Convert integer 1..20 to IEEE 754 half‑precision (fp16)
    function automatic logic [15:0] fp16(input int val);
        case (val)
            1:  return 16'h3C00;
            2:  return 16'h4000;
            3:  return 16'h4200;
            4:  return 16'h4400;
            5:  return 16'h4500;
            6:  return 16'h4600;
            7:  return 16'h4700;
            8:  return 16'h4800;
            9:  return 16'h4880;
           10:  return 16'h4900;
           11:  return 16'h4980;
           12:  return 16'h4A00;
           13:  return 16'h4A80;
           14:  return 16'h4B00;
           15:  return 16'h4B80;
           16:  return 16'h4C00;
           17:  return 16'h4C40;
           18:  return 16'h4C80;
           19:  return 16'h4CC0;
           20:  return 16'h4D00;
           default: return 16'h0000;
        endcase
    endfunction

    always #5 clk = ~clk;

    initial begin
        $dumpfile("build/systolic_top_tb.vcd");
        $dumpvars(0,systolic_top_tb);

        clk = 0;
        reset = 1;
        valid_in = 0;
        src_valid = 0;
        src_ready = 0;
        data_in = 0;

        #20;
        reset = 0;

        $monitor("%0t: state=%d, dest_ready=%b, src_valid=%b, tx_one_done=%b, load_in_done=%b",
            $time, dut.state, dut.dest_ready, src_valid, tx_one_done, dut.load_in_done);

        // Start transaction
        @(posedge clk);
        valid_in = 1;
        @(posedge clk);
        valid_in = 0;

        // Send 4 input packets, each = one row + one column in fp16
        for (int i = 0; i < 4; i = i + 1) begin
            data_in = {
                fp16(i*4+1), fp16(i*4+2), fp16(i*4+3), fp16(i*4+4),   // row i
                fp16(i*4+5), fp16(i*4+6), fp16(i*4+7), fp16(i*4+8)    // col i
            };
            src_valid = 1'b1;

            @(posedge tx_one_done);
            src_valid = 1'b0;
            @(negedge clk);   // small gap
        end
        $display("All inputs accepted.");

        // Receive 8 output chunks
        repeat(8) begin
            src_ready = 1;
            @(posedge tx_two_done);
            $display("%t Output = %h", $time, final_data_out);
            @(posedge clk);
            src_ready = 0;
        end

        // wait(done_matrix_mult); //// commenting just to see its simulations
        $display("DONE");
        #100;
        $finish;
    end

endmodule
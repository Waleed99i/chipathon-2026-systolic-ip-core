`timescale 1ns/1ps

module pe_tb;

    parameter N = 4;

    // DUT inputs
    reg clk;
    reg reset;
    reg valid;
    reg [15:0] A_in, B_in;

    // DUT outputs
    wire [31:0] y_out;
    wire [15:0] A_out, B_out;
    wire done;
    wire valid_out;

    // Instantiate DUT
    pe #(
        .N(N)
    ) dut (
        .clk(clk),
        .reset(reset),
        .valid(valid),
        .A_in(A_in),
        .B_in(B_in),
        .y_out(y_out),
        .A_out(A_out),
        .B_out(B_out),
        .done(done),
        .valid_out(valid_out)
    );

    // Clock generation
    always #5 clk = ~clk;

    integer i;

    // Example FP16 values
    reg [15:0] A_vals [0:6];
    reg [15:0] B_vals [0:6];

    initial begin

        clk = 0;

        // FP16 sample values
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

        reset = 1;
        valid = 0;
        A_in = 16'd0;
        B_in = 16'd0;

        // Hold reset
        #20;
        reset = 0;

        // Feed inputs
        for(i = 0; i < (2*N)-1; i = i + 1) begin

            @(posedge clk);
            A_in = A_vals[i];
            B_in = B_vals[i];
            valid = 1'b1;

            @(posedge clk);
            valid = 1'b0;

            // Wait for MAC completion
            wait(done == 1);

            $display("[%0t]", $time);
            $display("A_in      = 0x%h", A_in);
            $display("B_in      = 0x%h", B_in);
            $display("A_out     = 0x%h", A_out);
            $display("B_out     = 0x%h", B_out);
            $display("y_out     = 0x%h", y_out);
            $display("done      = %b", done);
            $display("valid_out = %b\n", valid_out);

            @(posedge clk);
            wait(done == 0);

            #20;

        end

        $display("PE Test Completed.");
        $finish;

    end

    initial begin
        $dumpfile("build/pe_tb.vcd");
        $dumpvars(0, pe_tb);
    end

endmodule
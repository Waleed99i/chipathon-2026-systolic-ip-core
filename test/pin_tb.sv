// SPDX-License-Identifier: Apache-2.0
// Pin-level replay of a vector file from test/a34_vectors.py.
// Uses ONLY the chip pins (clk, rst_n, input_in[7:0], output_out[3:0]) -- no
// internal signals -- so it checks the same timing a silicon tester relies on.
// Each vector line is one rising clock edge:  rst_n  in_byte  check  pins
// Inputs change on the falling edge before the rising edge; outputs are
// sampled on the falling edge after it (middle of the 2-cycle output window).
// Compile with -DGL -DFUNCTIONAL -DUSE_POWER_PINS for the gate-level netlist.
`timescale 1ns/1ps
module pin_tb;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg [7:0] input_in = 8'h00;
    wire [3:0] out;

`ifdef GL
    supply1 VDD; supply0 VSS;
`endif

    chip_core dut (
`ifdef GL
        .VDD(VDD), .VSS(VSS),
`endif
        .clk(clk), .rst_n(rst_n),
        .input_in_0(input_in[0]), .input_in_1(input_in[1]),
        .input_in_2(input_in[2]), .input_in_3(input_in[3]),
        .input_in_4(input_in[4]), .input_in_5(input_in[5]),
        .input_in_6(input_in[6]), .input_in_7(input_in[7]),
        .output_out_0_IN(1'b0), .output_out_0_OUT(out[0]),
        .output_out_1_IN(1'b0), .output_out_1_OUT(out[1]),
        .output_out_2_IN(1'b0), .output_out_2_OUT(out[2]),
        .output_out_3_IN(1'b0), .output_out_3_OUT(out[3])
    );

    always #5 clk = ~clk;   // 100 MHz in zero-delay simulation only

    integer fd, r, checked, errors, matrices;
    integer matrix_rows, matrix_checks, expected_matrices;
    reg [8*256-1:0] line;
    reg [7:0] v_rst, v_byte, v_chk, v_nib;

    initial begin
        if (!$value$plusargs("MATRICES=%d", expected_matrices) || expected_matrices <= 0)
            $fatal(1, "Supply positive +MATRICES=<expected case count>");
        if (!$value$plusargs("VEC=%s", line)) line = "vectors.vec";
        fd = $fopen(line, "r");
        if (fd == 0) $fatal(1, "cannot open vector file");
        checked = 0; errors = 0; matrices = 0;
        matrix_rows = 0; matrix_checks = 0;
        @(negedge clk);
        while (!$feof(fd)) begin
            r = $fgets(line, fd);
            if (r > 1 && line[8*r-1 -: 8] == "#") begin
                if (matrices > 0 && (matrix_rows != 390 || matrix_checks != 389))
                    $fatal(1, "Incomplete matrix: %0d rows, %0d checks", matrix_rows, matrix_checks);
                matrices = matrices + 1;
                matrix_rows = 0; matrix_checks = 0;
            end else if (r > 1 && $sscanf(line, "%h %h %h %h",
                                         v_rst, v_byte, v_chk, v_nib) == 4) begin
                if (matrices == 0 || v_rst > 1 || v_chk > 1 || v_nib > 15)
                    $fatal(1, "Invalid vector fields");
                matrix_rows = matrix_rows + 1;
                // inputs change on this falling edge
                rst_n = v_rst[0];
                input_in = v_byte;
                @(posedge clk);
                @(negedge clk);
                // sample in the middle of the clock period
                if (v_chk[0]) begin
                    checked = checked + 1;
                    matrix_checks = matrix_checks + 1;
                    if (out !== v_nib[3:0]) begin
                        errors = errors + 1;
                        if (errors <= 10)
                            $display("MISMATCH matrix %0d, check %0d: got %h expected %h",
                                     matrices, checked, out, v_nib[3:0]);
                    end
                end
            end else if (r > 1) $fatal(1, "Malformed vector line");
        end
        $display("PIN TEST: %0d matrices, %0d output samples checked, %0d mismatches",
                 matrices, checked, errors);
        if (errors == 0 && matrices == expected_matrices &&
            checked == 389 * expected_matrices && matrix_rows == 390 && matrix_checks == 389) begin
            $display("PIN TEST PASS");
            $finish;
        end
        $display("PIN TEST FAIL");
        $fatal(1, "pin test failed");
    end
    initial begin
        #100000000;
        $fatal(1, "Simulation timeout");
    end
endmodule

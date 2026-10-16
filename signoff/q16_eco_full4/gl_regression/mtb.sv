`timescale 1ns/1ps
// Multi-case matrix regression through the chip_core wrapper.
// One matrix per reset. Same byte timing as chip_core_tb (reset released just
// after a rising edge, one byte per clock, next packet after tx_one_done).
// Compile with -DGL for the powered gate-level netlist.
module mtb;
    parameter TIMEOUT_NS = 600000;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg [7:0] input_in = 8'h00;
    wire [3:0] bidir_in = 4'b0000;
    wire [3:0] bidir_out;

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
        .output_out_0_IN(bidir_in[0]), .output_out_0_OUT(bidir_out[0]),
        .output_out_1_IN(bidir_in[1]), .output_out_1_OUT(bidir_out[1]),
        .output_out_2_IN(bidir_in[2]), .output_out_2_OUT(bidir_out[2]),
        .output_out_3_IN(bidir_in[3]), .output_out_3_OUT(bidir_out[3])
    );

    wire tx1, tx2, sdone;
`ifdef GL
    assign tx1   = dut.\chip_core_internal_i.systolic_i.input_dp.rv_one.delay_reg_tx_done.y[0] ;
    assign tx2   = dut.\chip_core_internal_i.systolic_i.output_dp.rv_two.delay_reg_tx_done.y[0] ;
    assign sdone = dut.\chip_core_internal_i.systolic_done ;
`else
    assign tx1   = dut.chip_core_internal_i.systolic_tx_one_done;
    assign tx2   = dut.chip_core_internal_i.systolic_tx_two_done;
    assign sdone = dut.chip_core_internal_i.systolic_done;
`endif

    always #5 clk = ~clk;

    reg [127:0] pk [0:4*256-1];
    reg [3:0] chunks [0:127];
    integer ncase, c, p, b, e, k, outc;
    reg [127:0] packet;

    always @(posedge clk) begin
        if (rst_n && tx2 && outc < 128) begin
            if ($isunknown(bidir_out)) $fatal(1, "Unknown output nibble");
            chunks[outc] = bidir_out;
            outc = outc + 1;
        end
    end

    task send_byte(input [7:0] v);
        begin @(negedge clk); input_in = v; @(posedge clk); end
    endtask

    initial begin
        if (!$value$plusargs("N=%d", ncase)) ncase = 1;
        if (ncase < 1 || ncase > 256) $fatal(1, "Invalid case count");
        $readmemh("cases.hex", pk, 0, 4*ncase-1);
        outc = 0;
        for (c = 0; c < ncase; c = c + 1) begin
            rst_n = 1'b0; input_in = 8'h00;
            repeat (3) @(posedge clk);
            outc = 0;
            for (k = 0; k < 128; k = k + 1) chunks[k] = 4'hx;
            @(posedge clk);
            #1 rst_n = 1'b1;
            for (p = 0; p < 4; p = p + 1) begin
                packet = pk[4*c + p];
                for (b = 15; b >= 0; b = b - 1) send_byte(packet[8*b +: 8]);
                wait (tx1);
                @(posedge clk);
            end
            wait (sdone);
            wait (outc == 128);
            #1;
            for (e = 0; e < 16; e = e + 1)
                $display("CASE %0d ELEM %0d %h", c, e,
                    {chunks[8*e], chunks[8*e+1], chunks[8*e+2], chunks[8*e+3],
                     chunks[8*e+4], chunks[8*e+5], chunks[8*e+6], chunks[8*e+7]});
            $display("CASE %0d DONE at %0t", c, $time);
        end
        $finish;
    end

    initial begin
        #(TIMEOUT_NS); // 600,000 ns = 600 us at the declared timescale.
        $fatal(1, "TIMEOUT: matrix regression");
    end
endmodule

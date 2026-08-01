`timescale 1ps/1ps

module systolic_top_tb;

    logic clk;
    logic reset;
    logic valid_in;
    logic [63:0] data_in;
    logic src_valid;
    logic src_ready;
    logic [63:0] final_data_out;
    logic signed [31:0] el1;
    logic signed [31:0] el2;
    logic tx_one_done;

    assign el2 = final_data_out[31:0];
    assign el1 = final_data_out[63:32];
    logic done_matrix_mult;

    systolic dut (
        .clk(clk),
        .reset(reset),
        .valid_in(valid_in),
        .data_in(data_in),
        .src_valid(src_valid),
        .src_ready(src_ready),
        .final_data_out(final_data_out),
        .done_matrix_mult(done_matrix_mult),
        .tx_one_done(tx_one_done)
    );

    always #167 clk = ~clk; // Clock: 10ns period

    initial begin
        clk = 0;
        reset = 1;
        valid_in = 0;
        data_in = 64'd0;
        src_valid = 0;
        src_ready = 0;

        // ------------------------
        // FIRST RUN (positive integers)
        // ------------------------
        @(posedge clk);
        reset = 0;

        $display("== Starting Running Example 1 with positive integers ==");
        @(posedge clk);
        valid_in = 1;
        @(posedge clk);
        valid_in = #1 0;

        // First 64-bit chunk
        data_in = {
            8'd1,  8'd2,  8'd3,  8'd4,
            8'd1,  8'd5,  8'd9,  8'd13
        };
        @(posedge clk);
        src_valid = 1;
        @(posedge tx_one_done);
        //@(posedge clk);
        src_valid = 0;
        repeat(3) @(posedge clk);

        // Second chunk
        data_in = {
            8'd5,  8'd6,  8'd7,  8'd8,
            8'd2,  8'd6,  8'd10, 8'd14
        };
        @(posedge clk);
        src_valid = 1;
        @(posedge tx_one_done);
        //@(posedge clk);
        src_valid = 0;
        repeat(3) @(posedge clk);

        // Third chunk
        data_in = {
            8'd9,  8'd10, 8'd11, 8'd12,
            8'd3,  8'd7,  8'd11, 8'd15
        };
        @(posedge clk);
        src_valid = 1;
        @(posedge tx_one_done);
        //@(posedge clk);
        src_valid = 0;
        repeat(3) @(posedge clk);

        // Fourth chunk
        data_in = {
            8'd13, 8'd14, 8'd15, 8'd16,
            8'd4,  8'd8,  8'd12, 8'd16
        };
        @(posedge clk);
        src_valid = 1;
        @(posedge tx_one_done);
        //@(posedge clk);
        src_valid = 0;
        repeat(3) @(posedge clk);

        $display("The resulting Matrix for Example 1 is:");

        // Output DataPath Part
        for (int i = 0; i < 16; i++) begin
            src_ready = 1;
            wait(final_data_out);
            @(posedge clk);
            if (i < 4) begin
                $write("[ ");
                for (int j = 0; j < 4; j++) begin
                    $write("%0d ", dut.y_o[i][j]);
                end
                $write("]\n");
                end
            src_ready = 0;
        end
        $display("== Example 1 has been successfully finished ==");

        final_data_out = 0;

        repeat(10) @(posedge clk); // Wait for a few cycles before starting the next run




        // ------------------------
        // SECOND RUN (with negative integers too) & NO RESET
        // ------------------------
        $display("\n== Starting Running Example 2 with negative integers ==");
        @(posedge clk);
        valid_in = 1;
        @(posedge clk);
        valid_in = #1 0;

        // First chunk
        data_in = {
            8'd23,  8'd54,  -8'd65,  8'd32,
            8'd23,  -8'd73,  8'd92,  8'd1
        };
        @(posedge clk);
        src_valid = 1;
        @(posedge tx_one_done);
        //@(posedge clk);
        src_valid = 0;
        repeat(3) @(posedge clk);

        // Second chunk
        data_in = {
            -8'd73,  8'd37,  -8'd37,  8'd37,
            8'd54, -8'd37,  8'd61, 8'd2
        };
        @(posedge clk);
        src_valid = 1;
        @(posedge tx_one_done);
        //@(posedge clk);
        src_valid = 0;
        repeat(3) @(posedge clk);

        // Third chunk
        data_in = {
            8'd92,  -8'd61, 8'd31, 8'd30,
            8'd65,  8'd37, 8'd31, -8'd3
        };
        @(posedge clk);
        src_valid = 1;
        @(posedge tx_one_done);
        //@(posedge clk);
        src_valid = 0;
        repeat(3) @(posedge clk);

        // Fourth chunk
        data_in = {
            -8'd1, -8'd2, 8'd3, 8'd9,
            8'd32,  8'd37,  -8'd30, 8'd9
        };
        @(posedge clk);
        src_valid = 1;
        @(posedge tx_one_done);
        //@(posedge clk);
        src_valid = 0;
        repeat(3) @(posedge clk);

        $display("The resulting Matrix for Example 2 is:");

        for (int i = 0; i < 16; i++) begin
            src_ready = 1;
            wait(final_data_out);
            @(posedge clk);
            if (i < 4) begin
                $write("[ ");
                for (int j = 0; j < 4; j++) begin
                    $write("%0d ", dut.y_o[i][j]);
                end
                $write("]\n");
                end
            src_ready = 0;
        end
        $display("== Example 2 has been successfully finished ==");



        final_data_out = 0;

        repeat(10) @(posedge clk); // Wait for a few cycles before starting the next run




        // ------------------------
        // THIRD RUN (with negative integers too) & NO RESET
        // ------------------------
        $display("\n== Starting Running Example 3 with negative integers ==");
        @(posedge clk);
        valid_in = 1;
        @(posedge clk);
        valid_in = #1 0;

        // First chunk
        data_in = {
            8'd23,  8'd54,  -8'd65,  8'd32,
            8'd23,  -8'd73,  8'd92,  8'd1
        };
        @(posedge clk);
        src_valid = 1;
        @(posedge tx_one_done);
        //@(posedge clk);
        src_valid = 0;
        repeat(3) @(posedge clk);

        // Second chunk
        data_in = {
            -8'd73,  8'd37,  -8'd37,  8'd37,
            8'd59, -8'd37,  8'd61, 8'd2
        };
        @(posedge clk);
        src_valid = 1;
        @(posedge tx_one_done);
        //@(posedge clk);
        src_valid = 0;
        repeat(3) @(posedge clk);

        // Third chunk
        data_in = {
            8'd92,  8'd68, 8'd31, 8'd30,
            8'd65,  8'd37, 8'd31, -8'd3
        };
        @(posedge clk);
        src_valid = 1;
        @(posedge tx_one_done);
        //@(posedge clk);
        src_valid = 0;
        repeat(3) @(posedge clk);

        // Fourth chunk
        data_in = {
            -8'd1, -8'd2, 8'd3, 8'd9,
            8'd32,  8'd37,  -8'd30, 8'd9
        };
        @(posedge clk);
        src_valid = 1;
        @(posedge tx_one_done);
        //@(posedge clk);
        src_valid = 0;
        repeat(3) @(posedge clk);

        $display("The resulting Matrix for Example 3 is:");

        for (int i = 0; i < 16; i++) begin
            src_ready = 1;
            wait(final_data_out);
            @(posedge clk);
            if (i < 4) begin
                $write("[ ");
                for (int j = 0; j < 4; j++) begin
                    $write("%0d ", dut.y_o[i][j]);
                end
                $write("]\n");
                end
            src_ready = 0;
        end

        $display("== Example 3 has been successfully finished ==");

        final_data_out = 0;


        repeat(10) @(posedge clk); // Wait for a few cycles before starting the next run


     



        //-------------------------
        // FOURTH RUN (with negative integers too) & NO RESET
        //-------------------------
        $display("\n== Starting Running Example 4 with negative integers ==");
        @(posedge clk);
        valid_in = 1;
        @(posedge clk);
        valid_in = #1 0;

        // First chunk
        data_in = {
            8'd23,  8'd54,  -8'd65,  8'd32,
            8'd23,  -8'd73,  8'd92,  8'd1
        };
        @(posedge clk);
        src_valid = 1;
        @(posedge tx_one_done);
        //@(posedge clk);
        src_valid = 0;
        repeat(3) @(posedge clk);

        // Second chunk
        data_in = {
            -8'd73,  8'd37,  -8'd37,  8'd37,
            8'd54, -8'd37,  8'd61, 8'd2
        };
        @(posedge clk);
        src_valid = 1;
        @(posedge tx_one_done);
        //@(posedge clk);
        src_valid = 0;
        repeat(3) @(posedge clk);

        // Third chunk
        data_in = {
            8'd92,  -8'd61, -8'd56, 8'd30,
            8'd65,  8'd37, 8'd31, -8'd3
        };
        @(posedge clk);
        src_valid = 1;
        @(posedge tx_one_done);
        //@(posedge clk);
        src_valid = 0;
        repeat(3) @(posedge clk);

        // Fourth chunk
        data_in = {
            -8'd1, -8'd2, 8'd3, 8'd9,
            8'd9,  8'd37,  -8'd30, 8'd9
        };
        @(posedge clk);
        src_valid = 1;
        @(posedge tx_one_done);
        //@(posedge clk);
        src_valid = 0;
        repeat(3) @(posedge clk);

        $display("The resulting Matrix for Example 4 is:");

        for (int i = 0; i < 16; i++) begin
            src_ready = 1;
            wait(final_data_out);
            @(posedge clk);
            if (i < 4) begin
                $write("[ ");
                for (int j = 0; j < 4; j++) begin
                    $write("%0d ", dut.y_o[i][j]);
                end
                $write("]\n");
                end
            src_ready = 0;
        end

        $display("== Example 4 has been successfully finished ==");

        final_data_out = 0;


        repeat(10) @(posedge clk); // Wait for a few cycles before starting the next run






        //-------------------------
        // FIFTH RUN (with negative integers too) & NO RESET
        //-------------------------
        $display("\n== Starting Running Example 5 with negative integers ==");
        @(posedge clk);
        valid_in = 1;
        @(posedge clk);
        valid_in = #1 0;

        // First chunk
        data_in = {
            8'd23,  8'd54,  -8'd65,  8'd32,
            8'd23,  -8'd73,  8'd92,  8'd1
        };
        @(posedge clk);
        src_valid = 1;
        @(posedge tx_one_done);
        //@(posedge clk);
        src_valid = 0;
        repeat(3) @(posedge clk);

        // Second chunk
        data_in = {
            -8'd16,  8'd37,  8'd39,  8'd37,
            8'd54, -8'd37,  8'd61, 8'd2
        };
        @(posedge clk);
        src_valid = 1;
        @(posedge tx_one_done);
        //@(posedge clk);
        src_valid = 0;
        repeat(3) @(posedge clk);

        // Third chunk
        data_in = {
            8'd92,  -8'd61, 8'd31, 8'd30,
            8'd65,  8'd56, 8'd31, -8'd3
        };
        @(posedge clk);
        src_valid = 1;
        @(posedge tx_one_done);
        //@(posedge clk);
        src_valid = 0;
        repeat(3) @(posedge clk);

        // Fourth chunk
        data_in = {
            -8'd1, -8'd2, 8'd3, 8'd9,
            8'd32,  8'd37,  -8'd30, 8'd9
        };
        @(posedge clk);
        src_valid = 1;
        @(posedge tx_one_done);
        //@(posedge clk);
        src_valid = 0;
        repeat(3) @(posedge clk);

        $display("The resulting Matrix for Example 5 is:");


        for (int i = 0; i < 16; i++) begin
            src_ready = 1;
            wait(final_data_out);
            @(posedge clk);
            if (i < 4) begin
                $write("[ ");
                for (int j = 0; j < 4; j++) begin
                    $write("%0d ", dut.y_o[i][j]);
                end
                $write("]\n");
                end
            src_ready = 0;
        end

        $display("== Example 5 has been successfully finished ==");

        final_data_out = 0;

        repeat(10) @(posedge clk); // Wait for a few cycles before starting the next run






        //-------------------------
        // SIXTH RUN (with negative integers too) & NO RESET
        //-------------------------       
        $display("\n== Starting Running Example 6 with negative integers ==");
        @(posedge clk);
        valid_in = 1;
        @(posedge clk);
        valid_in = #1 0;

        // First chunk
        data_in = {
            8'd25,  8'd54,  -8'd65,  8'd32,
            8'd23,  -8'd73,  8'd92,  8'd1
        };
        @(posedge clk);
        src_valid = 1;
        @(posedge tx_one_done);
        //@(posedge clk);
        src_valid = 0;
        repeat(3) @(posedge clk);

        // Second chunk
        data_in = {
            -8'd73,  8'd37,  -8'd37,  8'd37,
            8'd54, -8'd37,  8'd61, 8'd2
        };
        @(posedge clk);
        src_valid = 1;
        @(posedge tx_one_done);
        //@(posedge clk);
        src_valid = 0;
        repeat(3) @(posedge clk);

        // Third chunk
        data_in = {
            8'd92,  -8'd61, 8'd31, 8'd30,
            8'd65,  8'd37, 8'd31, -8'd3
        };
        @(posedge clk);
        src_valid = 1;
        @(posedge tx_one_done);
        //@(posedge clk);
        src_valid = 0;
        repeat(3) @(posedge clk);

        // Fourth chunk
        data_in = {
            8'd1, -8'd2, 8'd3, 8'd9,
            8'd32,  8'd65,  -8'd30, 8'd9
        };
        @(posedge clk);
        src_valid = 1;
        @(posedge tx_one_done);
        //@(posedge clk);
        src_valid = 0;
        repeat(3) @(posedge clk);

        $display("The resulting Matrix for Example 6 is:");


        for (int i = 0; i < 16; i++) begin
            src_ready = 1;
            wait(final_data_out);
            @(posedge clk);
            if (i < 4) begin
                $write("[ ");
                for (int j = 0; j < 4; j++) begin
                    $write("%0d ", dut.y_o[i][j]);
                end
                $write("]\n");
                end
            src_ready = 0;
        end

        $display("== Example 6 has been successfully finished ==");
        final_data_out = 0;

      #25000000;
        $finish;
    end

endmodule
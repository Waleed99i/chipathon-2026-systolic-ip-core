`timescale 1ns/1ps

module systolic(
    input clk,
    input reset,

    input valid_in,
    input [127:0] data_in,

    input src_valid,
    input src_ready,

    output [3:0] final_data_out,

    output reg done_matrix_mult,
    output tx_one_done,
    output tx_two_done
);

    localparam IDLE        = 4'd0,
               RECEIVE     = 4'd1,
               IN_COUNT    = 4'd2,
               LOAD_IN     = 4'd3,
               LOAD_FEED   = 4'd10,
               FEED        = 4'd4,
               PROCESSING  = 4'd5,
               DONE        = 4'd6,
               LOAD_OUT    = 4'd7,
               TRANSFER    = 4'd8;

    reg [3:0] state;
    reg [3:0] next_state;

    // ------------------------------------------------------------------------
    // Input datapath connections
    // ------------------------------------------------------------------------

    wire signed [111:0] A_r [0:3];
    wire signed [111:0] B_c [0:3];

    wire signed [15:0] A_r_out [0:3];
    wire signed [15:0] B_c_out [0:3];

    wire load_in_done;

    // ------------------------------------------------------------------------
    // Systolic control signals
    // ------------------------------------------------------------------------

    reg sh_fr [0:3];
    reg sh_fc [0:3];

    reg load_fc [0:3];
    reg load_fr [0:3];

    wire done [0:3][0:3];
    wire valid_out [0:3][0:3];

    reg valid [0:3][0:3];

    reg dest_ready;
    reg next_col;
    reg next_row;

    reg load_out;
    reg dest_valid;
    reg shift;

    wire sh_count_done;

    reg res_internal;
    reg final_transfer;

    // ------------------------------------------------------------------------
    // Output transfer counter
    // ------------------------------------------------------------------------

    reg [6:0] output_transfer_count;

    always @(posedge clk or posedge reset) begin

        if (reset)
            output_transfer_count <= 7'd0;

        else if (state == IDLE)
            output_transfer_count <= 7'd0;

        else if (state == LOAD_OUT)
            output_transfer_count <= 7'd0;

        else if (state == TRANSFER && tx_two_done) begin

            if (output_transfer_count < 7'd127)
                output_transfer_count <= output_transfer_count + 1'b1;
            else
                output_transfer_count <= 7'd0;

        end

    end

    // ------------------------------------------------------------------------
    // Output signals from systolic array
    // ------------------------------------------------------------------------

    wire signed [31:0] y_o [0:3][0:3];
    wire [511:0] y;

    // ------------------------------------------------------------------------
    // Completion registers
    // ------------------------------------------------------------------------

    always @(posedge clk or posedge reset) begin

        if (reset)
            final_transfer <= 1'b0;

        else begin

            if (state == TRANSFER &&
                tx_two_done &&
                sh_count_done)

                final_transfer <= 1'b1;

            else if (state == IDLE)
                final_transfer <= 1'b0;

        end

    end

    always @(posedge clk or posedge reset) begin

        if (reset)
            done_matrix_mult <= 1'b0;

        else if (state == TRANSFER &&
                 tx_two_done &&
                 output_transfer_count == 7'd127)

            done_matrix_mult <= 1'b1;

        else if (state == IDLE)
            done_matrix_mult <= 1'b0;

    end

    always @(posedge clk or posedge reset) begin

        if (reset)
            res_internal <= 1'b0;

        else if (state == TRANSFER &&
                 tx_two_done &&
                 sh_count_done)

            res_internal <= 1'b1;

        else
            res_internal <= 1'b0;

    end

    // ------------------------------------------------------------------------
    // Input datapath
    // ------------------------------------------------------------------------

    input_datapath input_dp (
        .clk(clk),
        .reset(reset),
        .data_in(data_in),
        .src_valid(src_valid),
        .dest_ready(dest_ready),

        .next_row(next_row),
        .next_col(next_col),

        .load_in_done(load_in_done),
        .tx_one_done(tx_one_done),

        .B_c1(B_c[0]),
        .B_c2(B_c[1]),
        .B_c3(B_c[2]),
        .B_c4(B_c[3]),

        .A_r1(A_r[0]),
        .A_r2(A_r[1]),
        .A_r3(A_r[2]),
        .A_r4(A_r[3])
    );

    // ------------------------------------------------------------------------
    // Input data feeders
    // ------------------------------------------------------------------------

    genvar i;

    generate

        for(i = 0; i < 4; i = i + 1) begin : gen_A_rows

            data_feeder fri(
                .clk(clk),
                .data_in(A_r[i]),
                .shift(sh_fr[i]),
                .load(load_fr[i]),
                .reset(reset),
                .data_out(A_r_out[i])
            );

        end

        for(i = 0; i < 4; i = i + 1) begin : gen_B_cols

            data_feeder fci(
                .clk(clk),
                .data_in(B_c[i]),
                .shift(sh_fc[i]),
                .load(load_fc[i]),
                .reset(reset),
                .data_out(B_c_out[i])
            );

        end

    endgenerate

    // ------------------------------------------------------------------------
    // Systolic buses
    // ------------------------------------------------------------------------

    wire signed [15:0] A_bus [0:3][0:4];
    wire signed [15:0] B_bus [0:4][0:3];

    assign A_bus[0][0] = A_r_out[0];
    assign A_bus[1][0] = A_r_out[1];
    assign A_bus[2][0] = A_r_out[2];
    assign A_bus[3][0] = A_r_out[3];

    assign B_bus[0][0] = B_c_out[0];
    assign B_bus[0][1] = B_c_out[1];
    assign B_bus[0][2] = B_c_out[2];
    assign B_bus[0][3] = B_c_out[3];

    // ------------------------------------------------------------------------
    // 4x4 systolic array
    // ------------------------------------------------------------------------

    genvar m, n;

    generate

        for(m = 0; m < 4; m = m + 1) begin : ROW

            for(n = 0; n < 4; n = n + 1) begin : COL

                pe PEij(
                    .clk(clk),
                    .reset(reset || res_internal),
                    .valid(valid[m][n]),

                    .A_in(A_bus[m][n]),
                    .B_in(B_bus[m][n]),

                    .A_out(A_bus[m][n+1]),
                    .B_out(B_bus[m+1][n]),

                    .y_out(y_o[m][n]),

                    .done(done[m][n]),
                    .valid_out(valid_out[m][n])
                );

            end

        end

    endgenerate

    // ------------------------------------------------------------------------
    // Collect 16 PE outputs
    // ------------------------------------------------------------------------

    assign y = {
        y_o[0][0], y_o[0][1], y_o[0][2], y_o[0][3],
        y_o[1][0], y_o[1][1], y_o[1][2], y_o[1][3],
        y_o[2][0], y_o[2][1], y_o[2][2], y_o[2][3],
        y_o[3][0], y_o[3][1], y_o[3][2], y_o[3][3]
    };

    // ------------------------------------------------------------------------
    // Output datapath
    // ------------------------------------------------------------------------

    output_datapath output_dp(
        .clk(clk),
        .reset(reset),

        .load_out(load_out),
        .shift(shift),

        .src_ready(src_ready),

        .systolic_output(y),

        .dest_valid(dest_valid),

        .final_data_out(final_data_out),

        .sh_count_done(sh_count_done),
        .tx_two_done(tx_two_done)
    );

    // ------------------------------------------------------------------------
    // State register
    // ------------------------------------------------------------------------

    always @(posedge clk or posedge reset) begin

        if (reset)
            state <= IDLE;

        else
            state <= next_state;

    end
    
    // ========================================================================
    // BALANCED COMBINATIONAL DONE REDUCTION
    // ========================================================================
    //
    //          PE DONE SIGNALS
    //
    //   [0][0] [0][1] [0][2] [0][3]
    //       \     |     |     /
    //          AND-4
    //             |
    //        done_group_0
    //
    //   [1][0] [1][1] [1][2] [1][3]
    //       \     |     |     /
    //          AND-4
    //             |
    //        done_group_1
    //
    //   [2][0] [2][1] [2][2] [2][3]
    //       \     |     |     /
    //          AND-4
    //             |
    //        done_group_2
    //
    //   [3][0] [3][1] [3][2] [3][3]
    //       \     |     |     /
    //          AND-4
    //             |
    //        done_group_3
    //
    //             |
    //             v
    //          AND-4
    //             |
    //             v
    //         done_flag
    //
    // IMPORTANT:
    // No registers are used in this reduction tree.
    //
    // Therefore the entire reduction happens combinationally,
    // but the logic depth is only:
    //
    //       4-input AND -> 4-input AND
    //
    // instead of:
    //
    //       16-input AND
    //
    // ========================================================================

    wire done_group_0;
    wire done_group_1;
    wire done_group_2;
    wire done_group_3;

    wire done_flag;


    // ------------------------------------------------------------------------
    // Level 1: Four 4-input reductions
    // ------------------------------------------------------------------------

    assign done_group_0 =
            done[0][0] &&
            done[0][1] &&
            done[0][2] &&
            done[0][3];

    assign done_group_1 =
            done[1][0] &&
            done[1][1] &&
            done[1][2] &&
            done[1][3];

    assign done_group_2 =
            done[2][0] &&
            done[2][1] &&
            done[2][2] &&
            done[2][3];

    assign done_group_3 =
            done[3][0] &&
            done[3][1] &&
            done[3][2] &&
            done[3][3];


    // ------------------------------------------------------------------------
    // Level 2: Final reduction
    // ------------------------------------------------------------------------

    assign done_flag =
            done_group_0 &&
            done_group_1 &&
            done_group_2 &&
            done_group_3;

    // ------------------------------------------------------------------------
    // Combinational next-state logic
    // ------------------------------------------------------------------------

    reg valid_out_flag;

    integer x;
    integer z;

    always @(*) begin

        next_state = state;

        dest_ready = 1'b0;
        dest_valid = 1'b0;
        shift      = 1'b0;
        load_out   = 1'b0;

        for(x = 0; x < 4; x = x + 1) begin

            sh_fr[x]   = 1'b0;
            sh_fc[x]   = 1'b0;

            load_fr[x] = 1'b0;
            load_fc[x] = 1'b0;

            for(z = 0; z < 4; z = z + 1)
                valid[x][z] = 1'b0;

        end

        next_col = 1'b0;
        next_row = 1'b0;

        // --------------------------------------------------------------------
        // Check whether all PE outputs are valid
        // --------------------------------------------------------------------

        valid_out_flag =
                valid_out[0][0] && valid_out[0][1] &&
                valid_out[0][2] && valid_out[0][3] &&
                valid_out[1][0] && valid_out[1][1] &&
                valid_out[1][2] && valid_out[1][3] &&
                valid_out[2][0] && valid_out[2][1] &&
                valid_out[2][2] && valid_out[2][3] &&
                valid_out[3][0] && valid_out[3][1] &&
                valid_out[3][2] && valid_out[3][3];

        // --------------------------------------------------------------------
        // FSM
        // --------------------------------------------------------------------

        case(state)

            IDLE: begin

                if(valid_in) begin

                    next_state = RECEIVE;
                    dest_ready = 1'b1;

                end

                else begin

                    next_state = IDLE;

                end

            end

            RECEIVE: begin

                if(load_in_done) begin

                    next_state = LOAD_FEED;

                end

                else if(tx_one_done) begin

                    next_state = IN_COUNT;

                end

                else begin

                    dest_ready = 1'b1;
                    next_state = RECEIVE;

                end

            end

            IN_COUNT: begin

                if(load_in_done)
                    next_state = LOAD_FEED;

                else
                    next_state = LOAD_IN;

            end

            LOAD_IN: begin

                next_col   = 1'b1;
                next_row   = 1'b1;
                next_state = RECEIVE;

            end

            LOAD_FEED: begin

                for(x = 0; x < 4; x = x + 1) begin

                    load_fr[x] = 1'b1;
                    load_fc[x] = 1'b1;

                end

                next_state = FEED;

            end

            FEED: begin

                if(valid_out_flag) begin

                    next_state = DONE;

                end

                else begin

                    for(x = 0; x < 4; x = x + 1)
                        for(z = 0; z < 4; z = z + 1)
                            valid[x][z] = 1'b1;

                    next_state = PROCESSING;

                end

            end

          PROCESSING: begin

                if (valid_out_flag) begin
                    next_state = DONE;
                end
                else if (done_flag) begin

                    for(x = 0; x < 4; x = x + 1) begin
                        sh_fr[x] = 1'b1;
                        sh_fc[x] = 1'b1;
                    end

                    next_state = FEED;

                end
                else begin
                    next_state = PROCESSING;
                end

            end

            DONE: begin

                next_state = LOAD_OUT;

            end

            LOAD_OUT: begin

                load_out   = 1'b1;
                dest_valid = 1'b1;

                next_state = TRANSFER;

            end

            TRANSFER: begin

                dest_valid = 1'b1;

                if(tx_two_done) begin

                    if(sh_count_done) begin

                        next_col   = 1'b1;
                        next_row   = 1'b1;
                        next_state = IDLE;

                    end

                    else begin

                        shift      = 1'b1;
                        next_state = TRANSFER;

                    end

                end

                else begin

                    next_state = TRANSFER;

                end

            end

            default: begin

                next_state = IDLE;

            end

        endcase

    end

endmodule
`timescale 1ns/1ps

module input_datapath #(
    parameter N = 4,
    parameter DATA_WIDTH = 16
)(
    input clk,
    input reset,

    input [(DATA_WIDTH*(2*N))-1:0] data_in,

    input src_valid,
    input dest_ready,

    input next_row,
    input next_col,

    output load_in_done,
    output tx_one_done,

    output [(DATA_WIDTH*(2*N-1))-1:0] B_c1,
    output [(DATA_WIDTH*(2*N-1))-1:0] B_c2,
    output [(DATA_WIDTH*(2*N-1))-1:0] B_c3,
    output [(DATA_WIDTH*(2*N-1))-1:0] B_c4,

    output [(DATA_WIDTH*(2*N-1))-1:0] A_r1,
    output [(DATA_WIDTH*(2*N-1))-1:0] A_r2,
    output [(DATA_WIDTH*(2*N-1))-1:0] A_r3,
    output [(DATA_WIDTH*(2*N-1))-1:0] A_r4
);

    localparam INPUT_WIDTH  = DATA_WIDTH*(2*N);
    localparam OUTPUT_WIDTH = DATA_WIDTH*(2*N-1);
    localparam ROW_WIDTH    = DATA_WIDTH*N;

    wire [INPUT_WIDTH-1:0] protocol_out;

    wire row_done;
    wire col_done;

    wire [1:0] row_count;
    wire [1:0] col_count;

    wire [ROW_WIDTH-1:0] row_data;
    wire [ROW_WIDTH-1:0] col_data;

    wire [ROW_WIDTH-1:0] A_r [0:N-1];
    wire [ROW_WIDTH-1:0] B_c [0:N-1];


    rv_protocol #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH)
    ) rv_one (

        .clk(clk),
        .reset(reset),

        .valid(src_valid),
        .ready(dest_ready),

        .data_in(data_in),
        .data_out(protocol_out),

        .tx_done(tx_one_done)

    );


    controlled_counter #(
        .COUNT_LIMIT(N)
    ) row_counter (

        .clk(clk),
        .reset(reset),

        .enable(next_row),

        .count_done(row_done),
        .count(row_count)

    );


    controlled_counter #(
        .COUNT_LIMIT(N)
    ) col_counter (

        .clk(clk),
        .reset(reset),

        .enable(next_col),

        .count_done(col_done),
        .count(col_count)

    );


    assign load_in_done = row_done & col_done;


    assign row_data = protocol_out[INPUT_WIDTH-1:ROW_WIDTH];
    assign col_data = protocol_out[ROW_WIDTH-1:0];


    genvar i;

    generate

        for(i=0;i<N;i=i+1) begin : A_ROW_REGS

            reg_def #(
                .WIDTH(ROW_WIDTH)
            ) A_reg (

                .x(row_data),
                .enable(row_count==i),

                .clk(clk),
                .clear(reset),

                .y(A_r[i])

            );

        end

        for(i=0;i<N;i=i+1) begin : B_COL_REGS

            reg_def #(
                .WIDTH(ROW_WIDTH)
            ) B_reg (

                .x(col_data),
                .enable(col_count==i),

                .clk(clk),
                .clear(reset),

                .y(B_c[i])

            );

        end

    endgenerate


    assign A_r1 = {A_r[0], {(DATA_WIDTH*3){1'b0}}};
    assign A_r2 = {{DATA_WIDTH{1'b0}}, A_r[1], {(DATA_WIDTH*2){1'b0}}};
    assign A_r3 = {{(DATA_WIDTH*2){1'b0}}, A_r[2], {DATA_WIDTH{1'b0}}};
    assign A_r4 = {{(DATA_WIDTH*3){1'b0}}, A_r[3]};


    assign B_c1 = {B_c[0], {(DATA_WIDTH*3){1'b0}}};
    assign B_c2 = {{DATA_WIDTH{1'b0}}, B_c[1], {(DATA_WIDTH*2){1'b0}}};
    assign B_c3 = {{(DATA_WIDTH*2){1'b0}}, B_c[2], {DATA_WIDTH{1'b0}}};
    assign B_c4 = {{(DATA_WIDTH*3){1'b0}}, B_c[3]};

endmodule
`timescale 1ns/1ps

module rv_protocol #(
    parameter N = 4,
    parameter DATA_WIDTH = 16,  //FP16
    parameter INPUT_WIDTH = DATA_WIDTH*(2*N) // here for 4X4 it will be 16*8=128b or FP128
)(
    input clk,
    input reset,

    input valid,
    input ready,

    input  [INPUT_WIDTH-1:0] data_in,
    output [INPUT_WIDTH-1:0] data_out,

    output tx_done
);

reg en_data_Tx;

// FSM states
localparam IDLE         = 1'b0;
localparam TRANSFERRING = 1'b1;

reg state;
reg next_state;

// Data register
reg_def #(.WIDTH(INPUT_WIDTH)) rv_reg (
    .x(data_in),
    .enable(en_data_Tx),
    .clk(clk),
    .clear(reset),
    .y(data_out)
);

// State register
always @(posedge clk or posedge reset) begin
    if(reset)
        state <= IDLE;
    else
        state <= next_state;
end

// Next-state logic
always @(*) begin

    en_data_Tx = 1'b0;
    next_state = state;

    case(state)

        IDLE: begin

            if(valid && ready) begin
                en_data_Tx = 1'b1;
                next_state = TRANSFERRING;
            end

        end

        TRANSFERRING: begin
            next_state = IDLE;
        end

        default: begin
            next_state = IDLE;
        end

    endcase

end

// Delay tx_done by one clock
reg_def #(.WIDTH(1)) delay_reg_tx_done (

    .x(en_data_Tx),
    .enable(1'b1),
    .clk(clk),
    .clear(reset),
    .y(tx_done)

);

endmodule
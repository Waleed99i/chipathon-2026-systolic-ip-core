// it converts final_data_out = 64b to data_out=4b
// that will be covering 4 pins of our chip
 
`timescale 1ns/1ps

module output_serializer #(
    parameter DATA_WIDTH = 512,
    parameter OUT_WIDTH  = 4
)(
    input  logic                  clk,
    input  logic                  reset,

    // Load a new DATA_WIDTH-bit result
    input  logic                  valid_in,
    output logic                  ready_in,
    input  logic [DATA_WIDTH-1:0] data_in,

    // Serialized output
    output logic                  valid_out,
    input  logic                  ready_out,
    output logic [OUT_WIDTH-1:0]  data_out,

    // Indicates that the complete packet has been transmitted
    output logic                  done
);

    localparam integer NUM_CHUNKS = DATA_WIDTH / OUT_WIDTH;
    localparam integer COUNT_WIDTH =
        (NUM_CHUNKS <= 1) ? 1 : $clog2(NUM_CHUNKS);

    logic [DATA_WIDTH-1:0] shift_reg;
    logic [COUNT_WIDTH-1:0] count;

    logic busy;

    assign ready_in = ~busy;

    assign valid_out = busy;

    // MSB-first serialization
    assign data_out = shift_reg[DATA_WIDTH-1 -: OUT_WIDTH];

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            shift_reg <= '0;
            count     <= '0;
            busy      <= 1'b0;
            done      <= 1'b0;
        end
        else begin
            done <= 1'b0;

            // Load a new packet
            if (!busy) begin
                if (valid_in && ready_in) begin
                    shift_reg <= data_in;
                    count     <= '0;
                    busy      <= 1'b1;
                end
            end

            // Transmit one OUT_WIDTH-bit chunk
            else if (valid_out && ready_out) begin

                if (count == NUM_CHUNKS-1) begin
                    busy  <= 1'b0;
                    count <= '0;
                    done  <= 1'b1;
                end
                else begin
                    shift_reg <= shift_reg << OUT_WIDTH;
                    count     <= count + 1'b1;
                end
            end
        end
    end

endmodule

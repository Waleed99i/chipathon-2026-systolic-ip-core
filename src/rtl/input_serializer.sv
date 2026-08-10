// it converts data_in = 8bits --> 128b
// 128 then will go to the input_datapath 
`timescale 1ns/1ps

module input_serializer #(
    parameter INPUT_WIDTH  = 8,
    parameter OUTPUT_WIDTH = 128
)(
    input  wire                   clk,
    input  wire                   reset,

    // External 8-bit input stream
    input  wire [INPUT_WIDTH-1:0] data_in,
    input  wire                   valid_in,
    output wire                   ready_in,

    // Reconstructed 128-bit packet
    output reg  [OUTPUT_WIDTH-1:0] data_out,
    output reg                    valid_out,
    input  wire                    ready_out
);

    localparam NUM_TRANSFERS = OUTPUT_WIDTH / INPUT_WIDTH;
    localparam COUNT_WIDTH   = $clog2(NUM_TRANSFERS);

    reg [COUNT_WIDTH-1:0] count;
    reg [OUTPUT_WIDTH-1:0] buffer;

    /*
     * We can accept input bytes while the output packet is not
     * waiting to be consumed.
     */
    assign ready_in = ~valid_out;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            count     <= '0;
            buffer    <= '0;
            data_out  <= '0;
            valid_out <= 1'b0;
        end
        else begin

            /*
             * Output packet has been accepted by the downstream
             * module. Return to byte-collection mode.
             */
            if (valid_out && ready_out) begin
                valid_out <= 1'b0;
                count     <= '0;
            end

            /*
             * Accept an input byte.
             *
             * MSB-first:
             *   byte 0  -> [127:120]
             *   byte 1  -> [119:112]
             *   ...
             *   byte 15 -> [7:0]
             */
            if (valid_in && ready_in) begin

                buffer[
                    OUTPUT_WIDTH - 1 - (count * INPUT_WIDTH) -: INPUT_WIDTH
                ] <= data_in;

                if (count == NUM_TRANSFERS - 1) begin
                    /*
                     * Last byte received.
                     *
                     * Include the final byte explicitly because
                     * the nonblocking assignment to buffer above
                     * takes effect after this clock edge.
                     */
                    data_out[
                        OUTPUT_WIDTH - 1 - (count * INPUT_WIDTH) -: INPUT_WIDTH
                    ] <= data_in;

                    /*
                     * Copy the completed packet to the output.
                     */
                    data_out <= {
                        buffer[OUTPUT_WIDTH-1:INPUT_WIDTH],
                        data_in
                    };

                    valid_out <= 1'b1;
                    count     <= '0;
                end
                else begin
                    count <= count + 1'b1;
                end
            end
        end
    end

endmodule
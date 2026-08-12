// SPDX-FileCopyrightText: 2026 Chipathon 2026 workshop
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

module chip_core #(
    parameter NUM_INPUT_PADS  = 8,
    parameter NUM_BIDIR_PADS  = 4,
    parameter NUM_ANALOG_PADS = 1
)(
`ifdef USE_POWER_PINS
    inout wire VDD,
    inout wire VSS,
`endif

    input wire clk,
    input wire rst_n,

    // ------------------------------------------------------------
    // Input pads
    // ------------------------------------------------------------

    input wire [NUM_INPUT_PADS-1:0] input_in,

    output wire [NUM_INPUT_PADS-1:0] input_pu,
    output wire [NUM_INPUT_PADS-1:0] input_pd,

    // ------------------------------------------------------------
    // Bidirectional pads
    // ------------------------------------------------------------

    input wire [NUM_BIDIR_PADS-1:0] bidir_in,

    output wire [NUM_BIDIR_PADS-1:0] bidir_out,
    output wire [NUM_BIDIR_PADS-1:0] bidir_oe,
    output wire [NUM_BIDIR_PADS-1:0] bidir_cs,
    output wire [NUM_BIDIR_PADS-1:0] bidir_sl,
    output wire [NUM_BIDIR_PADS-1:0] bidir_ie,
    output wire [NUM_BIDIR_PADS-1:0] bidir_pu,
    output wire [NUM_BIDIR_PADS-1:0] bidir_pd,

    // ------------------------------------------------------------
    // Analog pads
    // ------------------------------------------------------------

    inout wire [NUM_ANALOG_PADS-1:0] analog
);

    // ============================================================
    // INPUT PACKET BUFFER
    //
    // One packet = 16 bytes = 128 bits
    //
    // We collect bytes directly here instead of relying on the
    // input_serializer handshake.
    // ============================================================

    reg [127:0] packet_buffer;

    reg [4:0] byte_count;

    reg packet_valid;
    reg packet_active;

    wire [7:0] input_byte;

    assign input_byte = input_in;

    // Four packets are required for a 4x4 matrix.
    reg [2:0] packet_count;

    // ============================================================
    // SYSTOLIC INTERFACE
    // ============================================================

    wire [3:0] systolic_output;

    wire systolic_done;
    wire systolic_tx_one_done;
    wire systolic_tx_two_done;

    // ============================================================
    // OUTPUT CONTROL
    //
    // Exactly 128 transfers:
    //
    // 512-bit result / 4-bit output = 128 transfers
    // ============================================================

    reg [7:0] output_count;

    wire output_active;

    assign output_active =
        (output_count < 8'd128) &&
        (systolic_tx_two_done);

    // ============================================================
    // SYSTOLIC
    // ============================================================

    systolic systolic_i (

        .clk   (clk),
        .reset (~rst_n),

        .valid_in (packet_valid),
        .data_in  (packet_buffer),

        .src_valid (packet_valid),
        .src_ready (1'b1),

        .final_data_out   (systolic_output),
        .done_matrix_mult (systolic_done),

        .tx_one_done (systolic_tx_one_done),
        .tx_two_done (systolic_tx_two_done)

    );

    // ============================================================
    // PACKET INPUT CONTROLLER
    //
    // The testbench drives one byte per clock.
    //
    // Byte 0  -> packet[127:120]
    // Byte 1  -> packet[119:112]
    // ...
    // Byte 15 -> packet[7:0]
    // ============================================================

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            packet_buffer <= 128'b0;
            byte_count    <= 5'd0;
            packet_valid  <= 1'b0;
            packet_active <= 1'b1;
            packet_count  <= 3'd0;

        end

        else begin

            // ----------------------------------------------------
            // packet_valid is a ONE-CYCLE pulse
            // ----------------------------------------------------

            packet_valid <= 1'b0;

            // ----------------------------------------------------
            // Receive bytes
            // ----------------------------------------------------

            if (packet_active) begin

                packet_buffer[
                    127 - (byte_count * 8) -: 8
                ] <= input_byte;

                // ------------------------------------------------
                // 16th byte
                // ------------------------------------------------

                if (byte_count == 5'd15) begin

                    byte_count <= 5'd0;

                    packet_valid <= 1'b1;

                    packet_count <= packet_count + 3'd1;

                    // Stop receiving until next packet
                    packet_active <= 1'b0;

                end

                else begin

                    byte_count <= byte_count + 5'd1;

                end

            end

            // ----------------------------------------------------
            // Wait for systolic to accept packet
            // ----------------------------------------------------

            else begin

                if (systolic_tx_one_done) begin

                    // Start next packet only if fewer than 4
                    // packets have been sent.

                    if (packet_count < 3'd4) begin

                        packet_active <= 1'b1;

                    end

                end

            end

        end

    end

    // ============================================================
    // OUTPUT COUNTER
    //
    // Count only the first 128 tx_two_done events.
    // ============================================================

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            output_count <= 8'd0;

        end

        else begin

            if (systolic_done) begin

                // Keep final count at 128.
                output_count <= 8'd128;

            end

            else if (systolic_tx_two_done &&
                     output_count < 8'd128) begin

                output_count <= output_count + 8'd1;

            end

        end

    end

    // ============================================================
    // OUTPUT PADS
    //
    // During the 128 output transfers, expose the systolic
    // 4-bit result.
    //
    // Otherwise drive zero.
    // ============================================================

    assign bidir_out =
        (output_count < 8'd128)
            ? systolic_output
            : 4'b0000;

    assign bidir_oe = 4'b1111;

    assign bidir_cs = 4'b0000;
    assign bidir_sl = 4'b0000;
    assign bidir_ie = 4'b0000;
    assign bidir_pu = 4'b0000;
    assign bidir_pd = 4'b0000;

    // ============================================================
    // INPUT PAD CONFIGURATION
    // ============================================================

    assign input_pu = {NUM_INPUT_PADS{1'b0}};
    assign input_pd = {NUM_INPUT_PADS{1'b0}};

    // ============================================================
    // UNUSED INPUT
    // ============================================================

    wire _unused;

    assign _unused = &{
        1'b0,
        bidir_in
    };

    // ============================================================
    // ANALOG
    // ============================================================

    generate

        if (NUM_ANALOG_PADS > 0) begin : gen_unused_analog

            assign analog = {NUM_ANALOG_PADS{1'bz}};

        end

    endgenerate

endmodule

`default_nettype wire

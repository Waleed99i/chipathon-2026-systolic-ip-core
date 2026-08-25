// SPDX-FileCopyrightText: 2026 Chipathon 2026 workshop
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

module chip_core_internal #(
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


// Organizer-facing interface matching A34_ACE.def (72 terminals).
// Original design preserved as chip_core_internal below.

module chip_core (
`ifdef USE_POWER_PINS
    inout wire VDD,
    inout wire VSS,
`endif

    output wire rst_n_PU,
    output wire rst_n_PD,
    input  wire rst_n,

    output wire clk_PU,
    output wire clk_PD,
    input  wire clk,

    output wire input_in_0_PU,
    output wire input_in_0_PD,
    input  wire input_in_0,
    output wire input_in_1_PU,
    output wire input_in_1_PD,
    input  wire input_in_1,
    output wire input_in_2_PU,
    output wire input_in_2_PD,
    input  wire input_in_2,
    output wire input_in_3_PU,
    output wire input_in_3_PD,
    input  wire input_in_3,
    output wire input_in_4_PU,
    output wire input_in_4_PD,
    input  wire input_in_4,
    output wire input_in_5_PU,
    output wire input_in_5_PD,
    input  wire input_in_5,
    output wire input_in_6_PU,
    output wire input_in_6_PD,
    input  wire input_in_6,
    output wire input_in_7_PU,
    output wire input_in_7_PD,
    input  wire input_in_7,

    output wire output_out_0_CS,
    output wire output_out_0_SL,
    output wire output_out_0_IE,
    output wire output_out_0_OE,
    output wire output_out_0_PU,
    output wire output_out_0_PD,
    output wire output_out_0_OUT,
    output wire output_out_0_PDRV0,
    output wire output_out_0_PDRV1,
    input  wire output_out_0_IN,

    output wire output_out_1_CS,
    output wire output_out_1_SL,
    output wire output_out_1_IE,
    output wire output_out_1_OE,
    output wire output_out_1_PU,
    output wire output_out_1_PD,
    output wire output_out_1_OUT,
    output wire output_out_1_PDRV0,
    output wire output_out_1_PDRV1,
    input  wire output_out_1_IN,

    output wire output_out_2_CS,
    output wire output_out_2_SL,
    output wire output_out_2_IE,
    output wire output_out_2_OE,
    output wire output_out_2_PU,
    output wire output_out_2_PD,
    output wire output_out_2_OUT,
    output wire output_out_2_PDRV0,
    output wire output_out_2_PDRV1,
    input  wire output_out_2_IN,

    output wire output_out_3_CS,
    output wire output_out_3_SL,
    output wire output_out_3_IE,
    output wire output_out_3_OE,
    output wire output_out_3_PU,
    output wire output_out_3_PD,
    output wire output_out_3_OUT,
    output wire output_out_3_PDRV0,
    output wire output_out_3_PDRV1,
    input  wire output_out_3_IN
);

    wire [7:0] input_in_bus;
    wire [7:0] input_pu_bus;
    wire [7:0] input_pd_bus;

    wire [3:0] bidir_in_bus;
    wire [3:0] bidir_out_bus;
    wire [3:0] bidir_oe_bus;
    wire [3:0] bidir_cs_bus;
    wire [3:0] bidir_sl_bus;
    wire [3:0] bidir_ie_bus;
    wire [3:0] bidir_pu_bus;
    wire [3:0] bidir_pd_bus;

    wire analog_unused;

    assign rst_n_PU = 1'b0;
    assign rst_n_PD = 1'b0;
    assign clk_PU   = 1'b0;
    assign clk_PD   = 1'b0;

    assign output_out_0_PDRV0 = 1'b0;
    assign output_out_0_PDRV1 = 1'b0;
    assign output_out_1_PDRV0 = 1'b0;
    assign output_out_1_PDRV1 = 1'b0;
    assign output_out_2_PDRV0 = 1'b0;
    assign output_out_2_PDRV1 = 1'b0;
    assign output_out_3_PDRV0 = 1'b0;
    assign output_out_3_PDRV1 = 1'b0;

    assign input_in_bus = {
        input_in_7, input_in_6, input_in_5, input_in_4,
        input_in_3, input_in_2, input_in_1, input_in_0
    };

    assign bidir_in_bus = {
        output_out_3_IN, output_out_2_IN,
        output_out_1_IN, output_out_0_IN
    };

    assign input_in_0_PU = input_pu_bus[0];
    assign input_in_1_PU = input_pu_bus[1];
    assign input_in_2_PU = input_pu_bus[2];
    assign input_in_3_PU = input_pu_bus[3];
    assign input_in_4_PU = input_pu_bus[4];
    assign input_in_5_PU = input_pu_bus[5];
    assign input_in_6_PU = input_pu_bus[6];
    assign input_in_7_PU = input_pu_bus[7];

    assign input_in_0_PD = input_pd_bus[0];
    assign input_in_1_PD = input_pd_bus[1];
    assign input_in_2_PD = input_pd_bus[2];
    assign input_in_3_PD = input_pd_bus[3];
    assign input_in_4_PD = input_pd_bus[4];
    assign input_in_5_PD = input_pd_bus[5];
    assign input_in_6_PD = input_pd_bus[6];
    assign input_in_7_PD = input_pd_bus[7];

    assign output_out_0_OUT = bidir_out_bus[0];
    assign output_out_1_OUT = bidir_out_bus[1];
    assign output_out_2_OUT = bidir_out_bus[2];
    assign output_out_3_OUT = bidir_out_bus[3];

    assign output_out_0_OE = bidir_oe_bus[0];
    assign output_out_1_OE = bidir_oe_bus[1];
    assign output_out_2_OE = bidir_oe_bus[2];
    assign output_out_3_OE = bidir_oe_bus[3];

    assign output_out_0_CS = bidir_cs_bus[0];
    assign output_out_1_CS = bidir_cs_bus[1];
    assign output_out_2_CS = bidir_cs_bus[2];
    assign output_out_3_CS = bidir_cs_bus[3];

    assign output_out_0_SL = bidir_sl_bus[0];
    assign output_out_1_SL = bidir_sl_bus[1];
    assign output_out_2_SL = bidir_sl_bus[2];
    assign output_out_3_SL = bidir_sl_bus[3];

    assign output_out_0_IE = bidir_ie_bus[0];
    assign output_out_1_IE = bidir_ie_bus[1];
    assign output_out_2_IE = bidir_ie_bus[2];
    assign output_out_3_IE = bidir_ie_bus[3];

    assign output_out_0_PU = bidir_pu_bus[0];
    assign output_out_1_PU = bidir_pu_bus[1];
    assign output_out_2_PU = bidir_pu_bus[2];
    assign output_out_3_PU = bidir_pu_bus[3];

    assign output_out_0_PD = bidir_pd_bus[0];
    assign output_out_1_PD = bidir_pd_bus[1];
    assign output_out_2_PD = bidir_pd_bus[2];
    assign output_out_3_PD = bidir_pd_bus[3];

    chip_core_internal #(
        .NUM_INPUT_PADS  (8),
        .NUM_BIDIR_PADS  (4),
        .NUM_ANALOG_PADS (1)
    ) chip_core_internal_i (
`ifdef USE_POWER_PINS
        .VDD (VDD),
        .VSS (VSS),
`endif
        .clk   (clk),
        .rst_n (rst_n),

        .input_in (input_in_bus),
        .input_pu (input_pu_bus),
        .input_pd (input_pd_bus),

        .bidir_in  (bidir_in_bus),
        .bidir_out (bidir_out_bus),
        .bidir_oe  (bidir_oe_bus),
        .bidir_cs  (bidir_cs_bus),
        .bidir_sl  (bidir_sl_bus),
        .bidir_ie  (bidir_ie_bus),
        .bidir_pu  (bidir_pu_bus),
        .bidir_pd  (bidir_pd_bus),

        .analog (analog_unused)
    );

endmodule

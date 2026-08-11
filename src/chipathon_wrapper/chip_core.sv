// SPDX-FileCopyrightText: 2026 Chipathon 2026 workshop
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

module chip_core #(
    parameter NUM_INPUT_PADS  = 8,
    parameter NUM_BIDIR_PADS  = 4,
    parameter NUM_ANALOG_PADS = 0
    )(
    `ifdef USE_POWER_PINS
        inout  wire VDD,
        inout  wire VSS,
    `endif

        input  wire clk,
        input  wire rst_n,

        
        // Input pads
        // 8 external input bits
        

        input  wire [NUM_INPUT_PADS-1:0] input_in,

        output wire [NUM_INPUT_PADS-1:0] input_pu,
        output wire [NUM_INPUT_PADS-1:0] input_pd,

        
        // Bidirectional pads
        // 4 output bits from systolic
        

        input  wire [NUM_BIDIR_PADS-1:0] bidir_in,

        output wire [NUM_BIDIR_PADS-1:0] bidir_out,
        output wire [NUM_BIDIR_PADS-1:0] bidir_oe,
        output wire [NUM_BIDIR_PADS-1:0] bidir_cs,
        output wire [NUM_BIDIR_PADS-1:0] bidir_sl,
        output wire [NUM_BIDIR_PADS-1:0] bidir_ie,
        output wire [NUM_BIDIR_PADS-1:0] bidir_pu,
        output wire [NUM_BIDIR_PADS-1:0] bidir_pd,

        
        // Analog pads
        

        inout wire [NUM_ANALOG_PADS-1:0] analog
    );


        
        // INPUT SERIALIZER
        //
        // External input:
        //
        //     8 bits
        //
        // The serializer collects:
        //
        //     16 × 8-bit transfers
        //
        // and produces:
        //
        //     1 × 128-bit packet
        //
        // The 128-bit packet then goes to systolic.
        

        wire [127:0] serialized_data;
        wire         serialized_valid;
        wire         serialized_ready;


        input_serializer #(
            .INPUT_WIDTH  (8),
            .OUTPUT_WIDTH (128)
        ) input_serializer_i (

            .clk       (clk),
            .reset     (~rst_n),

            .data_in   (input_in),
            .valid_in  (1'b1),
            .ready_in  (serialized_ready),

            .data_out  (serialized_data),
            .valid_out (serialized_valid),
            .ready_out (serialized_ready)

        );


        
        // SYSTOLIC ACCELERATOR
        //
        // Input:
        //
        //     128-bit packet
        //
        // Output:
        //
        //     4-bit serialized result
        //
        // The systolic module already contains the input datapath and
        // output datapath.
        

        wire [3:0] systolic_output;

        wire systolic_done;
        wire systolic_tx_one_done;
        wire systolic_tx_two_done;


        systolic systolic_i (

            .clk              (clk),
            .reset            (~rst_n),

            // Start/enable the input transaction when a complete
            // 128-bit packet is available.
            .valid_in         (serialized_valid),

            // Complete 128-bit packet from input_serializer.
            .data_in          (serialized_data),

            // Input datapath handshake.
            .src_valid        (serialized_valid),
            .src_ready        (1'b1),

            // 4-bit output stream.
            .final_data_out   (systolic_output),

            .done_matrix_mult (systolic_done),

            .tx_one_done      (systolic_tx_one_done),
            .tx_two_done      (systolic_tx_two_done)

        );


        
        // INPUT SERIALIZER READY
        //
        // The serializer must keep its completed 128-bit packet until the
        // systolic input datapath has accepted it.
        //
        // tx_one_done indicates that the systolic input transaction has
        // completed.
        

        assign serialized_ready = systolic_tx_one_done;


        
        // INPUT PAD CONFIGURATION
        

        assign input_pu = '0;
        assign input_pd = '0;


        
        // OUTPUT PADS
        //
        // Four bidirectional pads are used as the 4-bit output interface:
        //
        //     bidir_out[3:0] = systolic_output[3:0]
        //
        // All four are driven as outputs.
        

        assign bidir_out = systolic_output;

        assign bidir_oe = 4'b1111;

        assign bidir_cs = 4'b0000;
        assign bidir_sl = 4'b0000;

        // Output mode: input enable disabled.
        assign bidir_ie = 4'b0000;

        assign bidir_pu = 4'b0000;
        assign bidir_pd = 4'b0000;


        
        // UNUSED BIDIR INPUT
        //
        // These pads are being used as outputs, so bidir_in is intentionally
        // unused.
        

        wire _unused;

        assign _unused = &{
            1'b0,
            bidir_in,
            systolic_done,
            systolic_tx_two_done
        };


        
        // ANALOG PADS
        //
        // No analog functionality is used by this accelerator.
        

        generate

            if (NUM_ANALOG_PADS > 0) begin : gen_unused_analog

                assign analog = {NUM_ANALOG_PADS{1'bz}};

            end

        endgenerate


endmodule

`default_nettype wire
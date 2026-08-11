// SPDX-FileCopyrightText: © 2025 Project Template Contributors
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

`include "slot_defines.svh"

module chip_top #(
    // --------------------------------------------------------------------
    // Power / ground pads
    // --------------------------------------------------------------------

    parameter NUM_DVDD_PADS = `NUM_DVDD_PADS,
    parameter NUM_DVSS_PADS = `NUM_DVSS_PADS,

    // --------------------------------------------------------------------
    // Signal pads
    //
    // Our systolic accelerator uses:
    //
    //   8 input pads  -> input_serializer
    //   4 bidir pads  -> 4-bit systolic output
    //   0 analog pads
    // --------------------------------------------------------------------

    parameter NUM_INPUT_PADS  = 8,
    parameter NUM_BIDIR_PADS  = 4,
    parameter NUM_ANALOG_PADS = 0

    )(
    `ifdef USE_POWER_PINS

        inout wire VDD,
        inout wire VSS,

    `endif

        // --------------------------------------------------------------------
        // Clock / reset
        // --------------------------------------------------------------------

        inout wire clk_PAD,
        inout wire rst_n_PAD,

        // --------------------------------------------------------------------
        // Signal pads
        // --------------------------------------------------------------------

        inout wire [NUM_INPUT_PADS-1:0] input_PAD,
        inout wire [NUM_BIDIR_PADS-1:0] bidir_PAD,
        inout wire [NUM_ANALOG_PADS-1:0] analog_PAD
    );


        // ====================================================================
        // INTERNAL PAD SIGNALS
        // ====================================================================

        wire clk_PAD2CORE;
        wire rst_n_PAD2CORE;


        // Input pads

        wire [NUM_INPUT_PADS-1:0] input_PAD2CORE;

        wire [NUM_INPUT_PADS-1:0] input_CORE2PAD_PU;
        wire [NUM_INPUT_PADS-1:0] input_CORE2PAD_PD;


        // Bidirectional pads

        wire [NUM_BIDIR_PADS-1:0] bidir_PAD2CORE;

        wire [NUM_BIDIR_PADS-1:0] bidir_CORE2PAD;
        wire [NUM_BIDIR_PADS-1:0] bidir_CORE2PAD_OE;
        wire [NUM_BIDIR_PADS-1:0] bidir_CORE2PAD_CS;
        wire [NUM_BIDIR_PADS-1:0] bidir_CORE2PAD_SL;
        wire [NUM_BIDIR_PADS-1:0] bidir_CORE2PAD_IE;
        wire [NUM_BIDIR_PADS-1:0] bidir_CORE2PAD_PU;
        wire [NUM_BIDIR_PADS-1:0] bidir_CORE2PAD_PD;


        // ====================================================================
        // POWER / GROUND PADS
        // ====================================================================

        generate

            for (genvar i = 0; i < NUM_DVDD_PADS; i = i + 1) begin : dvdd_pads

                (* keep *)

                gf180mcu_ws_io__dvdd pad (

    `ifdef USE_POWER_PINS

                    .DVDD (VDD),
                    .DVSS (VSS),
                    .VSS  (VSS)

    `endif

                );

            end


            for (genvar i = 0; i < NUM_DVSS_PADS; i = i + 1) begin : dvss_pads

                (* keep *)

                gf180mcu_ws_io__dvss pad (

    `ifdef USE_POWER_PINS

                    .DVDD (VDD),
                    .DVSS (VSS),
                    .VDD  (VDD)

    `endif

                );

            end

        endgenerate


        // ====================================================================
        // CLOCK PAD
        // ====================================================================

        gf180mcu_fd_io__in_s clk_pad (

    `ifdef USE_POWER_PINS

            .DVDD (VDD),
            .DVSS (VSS),
            .VDD  (VDD),
            .VSS  (VSS),

    `endif

            .Y  (clk_PAD2CORE),
            .PAD(clk_PAD),

            .PU (1'b0),
            .PD (1'b0)

        );


        // ====================================================================
        // RESET PAD
        // ====================================================================

        gf180mcu_fd_io__in_c rst_n_pad (

    `ifdef USE_POWER_PINS

            .DVDD (VDD),
            .DVSS (VSS),
            .VDD  (VDD),
            .VSS  (VSS),

    `endif

            .Y  (rst_n_PAD2CORE),
            .PAD(rst_n_PAD),

            .PU (1'b0),
            .PD (1'b0)

        );


        // ====================================================================
        // 8 INPUT PADS
        //
        // External:
        //
        //     input_PAD[7:0]
        //
        // Internal:
        //
        //     input_PAD2CORE[7:0]
        //
        // These 8 bits go directly to input_serializer.sv.
        // ====================================================================

        generate

            for (genvar i = 0; i < NUM_INPUT_PADS; i = i + 1) begin : inputs

                (* keep *)

                gf180mcu_fd_io__in_c pad (

    `ifdef USE_POWER_PINS

                    .DVDD (VDD),
                    .DVSS (VSS),
                    .VDD  (VDD),
                    .VSS  (VSS),

    `endif

                    .Y  (input_PAD2CORE[i]),
                    .PAD(input_PAD[i]),

                    .PU(input_CORE2PAD_PU[i]),
                    .PD(input_CORE2PAD_PD[i])

                );

            end

        endgenerate


        // ====================================================================
        // 4 BIDIRECTIONAL PADS
        //
        // These are used as the 4-bit output interface:
        //
        //     systolic final_data_out[3:0]
        //                    │
        //                    ▼
        //             bidir_PAD[3:0]
        //
        // chip_core controls OE/IE.
        // ====================================================================

        generate

            for (genvar i = 0; i < NUM_BIDIR_PADS; i = i + 1) begin : bidir

                (* keep *)

                gf180mcu_fd_io__bi_24t pad (

    `ifdef USE_POWER_PINS

                    .DVDD (VDD),
                    .DVSS (VSS),
                    .VDD  (VDD),
                    .VSS  (VSS),

    `endif

                    .A  (bidir_CORE2PAD[i]),
                    .OE (bidir_CORE2PAD_OE[i]),
                    .Y  (bidir_PAD2CORE[i]),
                    .PAD(bidir_PAD[i]),

                    .CS(bidir_CORE2PAD_CS[i]),
                    .SL(bidir_CORE2PAD_SL[i]),
                    .IE(bidir_CORE2PAD_IE[i]),
                    .PU(bidir_CORE2PAD_PU[i]),
                    .PD(bidir_CORE2PAD_PD[i])

                );

            end

        endgenerate


        // ====================================================================
        // ANALOG PADS
        //
        // NUM_ANALOG_PADS = 0 for our design, therefore this generate block
        // produces no instances.
        // ====================================================================

        generate

            for (genvar i = 0; i < NUM_ANALOG_PADS; i = i + 1) begin : analog

                (* keep *)

                gf180mcu_fd_io__asig_5p0 pad (

    `ifdef USE_POWER_PINS

                    .DVDD (VDD),
                    .DVSS (VSS),
                    .VDD  (VDD),
                    .VSS  (VSS),

    `endif

                    .ASIG5V(analog_PAD[i])

                );

            end

        endgenerate


        // ====================================================================
        // CHIP CORE
        // ====================================================================

        chip_core #(

            .NUM_INPUT_PADS  (NUM_INPUT_PADS),
            .NUM_BIDIR_PADS  (NUM_BIDIR_PADS),
            .NUM_ANALOG_PADS (NUM_ANALOG_PADS)

        ) i_chip_core (

    `ifdef USE_POWER_PINS

            .VDD(VDD),
            .VSS(VSS),

    `endif

            .clk  (clk_PAD2CORE),
            .rst_n(rst_n_PAD2CORE),


            // ---------------------------------------------------------------
            // 8-bit input stream
            // ---------------------------------------------------------------

            .input_in(input_PAD2CORE),

            .input_pu(input_CORE2PAD_PU),
            .input_pd(input_CORE2PAD_PD),


            // ---------------------------------------------------------------
            // 4-bit output stream
            // ---------------------------------------------------------------

            .bidir_in (bidir_PAD2CORE),

            .bidir_out(bidir_CORE2PAD),
            .bidir_oe (bidir_CORE2PAD_OE),
            .bidir_cs (bidir_CORE2PAD_CS),
            .bidir_sl (bidir_CORE2PAD_SL),
            .bidir_ie (bidir_CORE2PAD_IE),
            .bidir_pu (bidir_CORE2PAD_PU),
            .bidir_pd (bidir_CORE2PAD_PD),


            // ---------------------------------------------------------------
            // No analog pads
            // ---------------------------------------------------------------

            .analog(analog_PAD)

        );


        // ====================================================================
        // CHIP ID
        //
        // Required for tapeout.
        // ====================================================================

        (* keep *)

        gf180mcu_ws_ip__id chip_id ();


        // ====================================================================
        // WAFER.SPACE LOGO
        // ====================================================================

        (* keep *)

        gf180mcu_ws_ip__logo wafer_space_logo ();


endmodule

`default_nettype wire
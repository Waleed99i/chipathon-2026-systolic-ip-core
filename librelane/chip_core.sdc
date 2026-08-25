###############################################################################
# A34 chip_core timing constraints
###############################################################################
current_design chip_core

create_clock -name clk -period 45.0000 [get_ports {clk}]
set_clock_transition 0.1500 [get_clocks {clk}]
set_clock_uncertainty 0.2500 [get_clocks {clk}]
set_propagated_clock [get_clocks {clk}]

set data_inputs [get_ports {rst_n input_in_0 input_in_1 input_in_2 input_in_3 input_in_4 input_in_5 input_in_6 input_in_7 output_out_0_IN output_out_1_IN output_out_2_IN output_out_3_IN}]

set_input_delay 8.0000     -clock [get_clocks {clk}] -add_delay $data_inputs

set_output_delay 8.0000     -clock [get_clocks {clk}] -add_delay [all_outputs]

set_load -pin_load 0.0729 [all_outputs]

set_driving_cell     -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_1     -pin {ZN}     -input_transition_rise 0.0000     -input_transition_fall 0.0000     $data_inputs

set_driving_cell     -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_4     -pin {ZN}     -input_transition_rise 0.0000     -input_transition_fall 0.0000     [get_ports {clk}]

set_max_transition 3.0000 [current_design]
set_max_capacitance 0.2000 [current_design]
set_max_fanout 10.0000 [current_design]

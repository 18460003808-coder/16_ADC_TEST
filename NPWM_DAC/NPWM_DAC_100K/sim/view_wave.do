vsim -view vsim.wlf
add wave -divider "Inputs"
add wave sim:/tb_npwm_dac_100k/sysclk
add wave sim:/tb_npwm_dac_100k/rst_n
add wave sim:/tb_npwm_dac_100k/rst_pwm_n
add wave sim:/tb_npwm_dac_100k/trig
add wave -divider "100 kHz PWM"
add wave -radix unsigned sim:/tb_npwm_dac_100k/pwm_duty
add wave sim:/tb_npwm_dac_100k/pwm_out
add wave -radix unsigned sim:/tb_npwm_dac_100k/dut/pwm_slot
add wave -radix unsigned sim:/tb_npwm_dac_100k/dut/slot_clock
wave zoom full


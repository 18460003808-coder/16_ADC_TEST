vsim -view vsim.wlf
add wave -divider "Inputs"
add wave sim:/tb_npwm_dac_50k/sysclk
add wave sim:/tb_npwm_dac_50k/rst_n
add wave sim:/tb_npwm_dac_50k/rst_pwm_n
add wave sim:/tb_npwm_dac_50k/trig
add wave -divider "50 kHz PWM"
add wave -radix unsigned sim:/tb_npwm_dac_50k/pwm_duty
add wave sim:/tb_npwm_dac_50k/pwm_out
add wave -radix unsigned sim:/tb_npwm_dac_50k/dut/pwm_counter
wave zoom full


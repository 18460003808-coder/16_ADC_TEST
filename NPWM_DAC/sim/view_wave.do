vsim -view vsim.wlf
add wave -divider "Inputs"
add wave sim:/tb_npwm_dac/sysclk
add wave sim:/tb_npwm_dac/rst_n
add wave sim:/tb_npwm_dac/rst_pwm_n
add wave sim:/tb_npwm_dac/trig
add wave -divider "PWM"
add wave -radix unsigned sim:/tb_npwm_dac/pwm_duty
add wave sim:/tb_npwm_dac/pwm_out
add wave -radix unsigned sim:/tb_npwm_dac/dut/pwm_counter
wave zoom full


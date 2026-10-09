vsim -view vsim.wlf
add wave -divider "Inputs"
add wave sim:/tb_npwm_dac_adjustable/sysclk
add wave sim:/tb_npwm_dac_adjustable/rst_n
add wave sim:/tb_npwm_dac_adjustable/rst_pwm_n
add wave sim:/tb_npwm_dac_adjustable/trig
add wave -radix unsigned sim:/tb_npwm_dac_adjustable/period_count
add wave -divider "PWM"
add wave -radix unsigned sim:/tb_npwm_dac_adjustable/dut/active_period
add wave -radix unsigned sim:/tb_npwm_dac_adjustable/pwm_duty
add wave sim:/tb_npwm_dac_adjustable/pwm_out
add wave -radix unsigned sim:/tb_npwm_dac_adjustable/dut/pwm_slot
wave zoom full


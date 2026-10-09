transcript on

if {![file isdirectory work]} {
    vlib work
}
vmap work work

vlog -work work rtl/ads7953_16ch_reader.v
vlog -work work rtl/uart_8n1.v
vlog -work work slide.v
vlog -work work rtl/ads7953_Nboard_controller.v
vlog -work work rtl/ads7953_Nboard_uart_bridge.v
vlog -work work rtl/ads7953_Nboard_top.v
vlog -work work rtl/ads7953_Nboard_hw_top.v
vlog -work work sim/tb_ads7953_Nboard.v

vsim -voptargs=+acc work.tb_ads7953_Nboard

add wave -radix binary sim:/tb_ads7953_Nboard/clk
add wave -radix binary sim:/tb_ads7953_Nboard/rst_n
add wave -radix binary sim:/tb_ads7953_Nboard/ready
add wave -radix binary sim:/tb_ads7953_Nboard/busy
add wave -radix hex    sim:/tb_ads7953_Nboard/adc_cs_n
add wave -radix binary sim:/tb_ads7953_Nboard/adc_sclk
add wave -radix binary sim:/tb_ads7953_Nboard/adc_sdi
add wave -radix binary sim:/tb_ads7953_Nboard/adc_sdo
add wave -radix binary sim:/tb_ads7953_Nboard/sample_valid
add wave -radix unsigned sim:/tb_ads7953_Nboard/sample_board
add wave -radix unsigned sim:/tb_ads7953_Nboard/sample_channel
add wave -radix hex sim:/tb_ads7953_Nboard/sample_code
add wave -radix unsigned sim:/tb_ads7953_Nboard/dut/u_uart_bridge/packet_board
add wave -radix unsigned sim:/tb_ads7953_Nboard/dut/u_uart_bridge/byte_index

run -all

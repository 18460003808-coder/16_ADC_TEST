transcript on

if {![file isdirectory work]} {
    vlib work
}
vmap work work

vlog -work work rtl/ads7953_16ch_reader.v
vlog -work work rtl/uart_8n1.v
vlog -work work rtl/ads7953_20board_controller.v
vlog -work work rtl/ads7953_20board_uart_bridge.v
vlog -work work rtl/ads7953_20board_top.v
vlog -work work rtl/ads7953_20board_hw_top.v
vlog -work work sim/tb_ads7953_20board.v

vsim -voptargs=+acc work.tb_ads7953_20board

add wave -radix binary sim:/tb_ads7953_20board/clk
add wave -radix binary sim:/tb_ads7953_20board/rst_n
add wave -radix binary sim:/tb_ads7953_20board/ready
add wave -radix binary sim:/tb_ads7953_20board/busy
add wave -radix hex    sim:/tb_ads7953_20board/adc_cs_n
add wave -radix binary sim:/tb_ads7953_20board/adc_sclk
add wave -radix binary sim:/tb_ads7953_20board/adc_sdi
add wave -radix binary sim:/tb_ads7953_20board/adc_sdo
add wave -radix binary sim:/tb_ads7953_20board/sample_valid
add wave -radix unsigned sim:/tb_ads7953_20board/sample_board
add wave -radix unsigned sim:/tb_ads7953_20board/sample_channel
add wave -radix hex sim:/tb_ads7953_20board/sample_code
add wave -radix unsigned sim:/tb_ads7953_20board/dut/u_uart_bridge/packet_board
add wave -radix unsigned sim:/tb_ads7953_20board/dut/u_uart_bridge/byte_index

run -all

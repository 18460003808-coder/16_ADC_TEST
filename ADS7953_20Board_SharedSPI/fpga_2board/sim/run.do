# ADS7953 two-board shared-SPI self-checking simulation
# Run from fpga_2board:
#   vsim -c -do "do sim/run.do; quit -f"

transcript on

if {![file isdirectory work]} {
    vlib work
}
vmap work work

vlog -work work rtl/ads7953_16ch_reader.v
vlog -work work rtl/uart_8n1.v
vlog -work work rtl/ads7953_2board_controller.v
vlog -work work rtl/ads7953_2board_uart_bridge.v
vlog -work work rtl/ads7953_2board_top.v
vlog -work work rtl/ads7953_2board_hw_top.v
vlog -work work sim/tb_ads7953_2board.v

vsim -voptargs=+acc work.tb_ads7953_2board

add wave -divider "Control"
add wave -radix binary sim:/tb_ads7953_2board/clk
add wave -radix binary sim:/tb_ads7953_2board/rst_n
add wave -radix binary sim:/tb_ads7953_2board/ready
add wave -radix binary sim:/tb_ads7953_2board/busy
add wave -radix binary sim:/tb_ads7953_2board/packet_busy

add wave -divider "Shared SPI"
add wave -radix binary sim:/tb_ads7953_2board/adc_cs_n
add wave -radix binary sim:/tb_ads7953_2board/adc_sclk
add wave -radix binary sim:/tb_ads7953_2board/adc_sdi
add wave -radix binary sim:/tb_ads7953_2board/adc_sdo
add wave -radix binary sim:/tb_ads7953_2board/sdo0
add wave -radix binary sim:/tb_ads7953_2board/sdo1

add wave -divider "Samples"
add wave -radix binary   sim:/tb_ads7953_2board/sample_valid
add wave -radix unsigned sim:/tb_ads7953_2board/sample_board
add wave -radix unsigned sim:/tb_ads7953_2board/sample_channel
add wave -radix hex      sim:/tb_ads7953_2board/sample_code
add wave -radix hex      sim:/tb_ads7953_2board/dut/u_controller/board_codes

add wave -divider "UART"
add wave -radix binary sim:/tb_ads7953_2board/uart_rxd
add wave -radix binary sim:/tb_ads7953_2board/uart_txd
add wave -radix unsigned sim:/tb_ads7953_2board/dut/u_uart_bridge/packet_board
add wave -radix unsigned sim:/tb_ads7953_2board/dut/u_uart_bridge/byte_index

run -all

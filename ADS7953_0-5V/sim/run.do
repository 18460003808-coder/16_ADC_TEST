# ADS7953 16-channel reader - ModelSim one-click simulation
# Run from the project root:
#   vsim -do sim/run.do

transcript on

if {![file isdirectory work]} {
    vlib work
}
vmap work work

vlog -work work rtl/ads7953_16ch_reader.v
vlog -work work rtl/uart_8n1.v
vlog -work work rtl/ads7953_uart_bridge.v
vlog -work work rtl/ads7953_top.v
vlog -work work sim/tb_ads7953_16ch_reader.v

vsim -voptargs=+acc work.tb_ads7953_16ch_reader

add wave -divider "Clock / control"
add wave -radix binary  sim:/tb_ads7953_16ch_reader/clk
add wave -radix binary  sim:/tb_ads7953_16ch_reader/rst_n
add wave -radix binary  sim:/tb_ads7953_16ch_reader/trig_internal
add wave -radix binary  sim:/tb_ads7953_16ch_reader/uart_rxd
add wave -radix binary  sim:/tb_ads7953_16ch_reader/uart_txd
add wave -radix binary  sim:/tb_ads7953_16ch_reader/uart_packet_busy
add wave -radix binary  sim:/tb_ads7953_16ch_reader/ready
add wave -radix binary  sim:/tb_ads7953_16ch_reader/busy
add wave -radix binary  sim:/tb_ads7953_16ch_reader/scan_done
add wave -radix unsigned sim:/tb_ads7953_16ch_reader/dut/u_ads7953_reader/state
add wave -radix unsigned sim:/tb_ads7953_16ch_reader/dut/u_ads7953_reader/discard_count
add wave -radix binary  sim:/tb_ads7953_16ch_reader/dut/u_ads7953_reader/collecting
add wave -radix unsigned sim:/tb_ads7953_16ch_reader/dut/u_ads7953_reader/expected_channel

add wave -divider "ADS7953 SPI"
add wave -radix binary  sim:/tb_ads7953_16ch_reader/cs_n
add wave -radix binary  sim:/tb_ads7953_16ch_reader/sclk
add wave -radix binary  sim:/tb_ads7953_16ch_reader/sdi
add wave -radix binary  sim:/tb_ads7953_16ch_reader/sdo
add wave -radix hex     sim:/tb_ads7953_16ch_reader/dut/u_ads7953_reader/tx_word
add wave -radix hex     sim:/tb_ads7953_16ch_reader/dut/u_ads7953_reader/rx_shift
add wave -radix hex     sim:/tb_ads7953_16ch_reader/response
add wave -radix hex     sim:/tb_ads7953_16ch_reader/mosi_shift

add wave -divider "Sample stream"
add wave -radix binary  sim:/tb_ads7953_16ch_reader/sample_valid
add wave -radix unsigned sim:/tb_ads7953_16ch_reader/sample_channel
add wave -radix hex     sim:/tb_ads7953_16ch_reader/sample_code
add wave -radix unsigned sim:/tb_ads7953_16ch_reader/sample_mv

add wave -divider "All channel codes"
add wave -radix hex sim:/tb_ads7953_16ch_reader/adc_codes
add wave -radix hex sim:/tb_ads7953_16ch_reader/model_base
add wave -radix unsigned sim:/tb_ads7953_16ch_reader/sample_events

configure wave -namecolwidth 260
configure wave -valuecolwidth 120
run -all
wave zoom full

transcript on

if {![file isdirectory work7]} {
    vlib work7
}
vmap work7 work7

vlog -work work7 rtl/ads7953_16ch_reader.v
vlog -work work7 rtl/uart_8n1.v
vlog -work work7 rtl/ads7953_Nboard_controller.v
vlog -work work7 rtl/ads7953_Nboard_uart_bridge.v
vlog -work work7 +define+ADS7953_BOARD_COUNT=7 rtl/ads7953_Nboard_top.v
vlog -work work7 rtl/ads7953_Nboard_hw_top.v
vlog -work work7 +define+ADS7953_BOARD_COUNT=7 sim/tb_ads7953_Nboard.v

vsim -voptargs=+acc work7.tb_ads7953_Nboard
run -all

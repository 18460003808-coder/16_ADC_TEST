transcript on

if {[file isdirectory work]} {
    vdel -lib work -all
}
vlib work
vmap work work

vlog -work work +define+ADS7953_BOARD_COUNT=20 rtl/ads7953_16ch_reader.v
vlog -work work +define+ADS7953_BOARD_COUNT=20 rtl/uart_8n1.v
vlog -work work +define+ADS7953_BOARD_COUNT=20 slide.v
vlog -work work +define+ADS7953_BOARD_COUNT=20 rtl/ads7953_Nboard_controller.v
vlog -work work +define+ADS7953_BOARD_COUNT=20 rtl/ads7953_Nboard_uart_bridge.v
vlog -work work +define+ADS7953_BOARD_COUNT=20 rtl/ads7953_Nboard_top.v
vlog -work work +define+ADS7953_BOARD_COUNT=20 rtl/ads7953_Nboard_hw_top.v
vlog -work work +define+ADS7953_BOARD_COUNT=20 sim/tb_ads7953_Nboard.v

vsim -c -voptargs=+acc work.tb_ads7953_Nboard
run -all

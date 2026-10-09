if {[file exists work]} {vdel -lib work -all}
vlib work
vlog -work work +define+TEST_BOARD_COUNT=20 rtl/ads7953_udp_gmii.v
vlog -work work +define+TEST_BOARD_COUNT=20 sim/tb_ads7953_udp_gmii.v
vsim -c work.tb_ads7953_udp_gmii
run -all

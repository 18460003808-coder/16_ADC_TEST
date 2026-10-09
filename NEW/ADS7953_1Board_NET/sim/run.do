if {[file exists work]} {vdel -lib work -all}
vlib work
vlog -work work rtl/ads7953_16ch_reader.v sim/tb_1board_reader.v
vsim -c work.tb_1board_reader
run -all

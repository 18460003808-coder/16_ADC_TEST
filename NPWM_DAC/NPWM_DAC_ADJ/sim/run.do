if {![file isdirectory work]} {
    vlib work
}
vmap work work
vlog ../rtl/npwm_dac_adjustable.v tb_npwm_dac_adjustable.v
vsim -voptargs=+acc work.tb_npwm_dac_adjustable
log -r /*
run -all
quit -f


if {![file isdirectory work]} {
    vlib work
}
vmap work work
vlog ../rtl/npwm_dac.v tb_npwm_dac.v
vsim -voptargs=+acc work.tb_npwm_dac
log -r /*
run -all
quit -f


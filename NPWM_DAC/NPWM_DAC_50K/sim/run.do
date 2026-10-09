if {![file isdirectory work]} {
    vlib work
}
vmap work work
vlog ../rtl/npwm_dac_50k.v tb_npwm_dac_50k.v
vsim -voptargs=+acc work.tb_npwm_dac_50k
log -r /*
run -all
quit -f


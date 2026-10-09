transcript on

if {[file isdirectory work]} {
    vdel -lib work -all
}
vlib work
vmap work work

vlog -work work slide.v
vlog -work work sim/tb_slide.v

vsim -c -voptargs=+acc work.tb_slide
run -all

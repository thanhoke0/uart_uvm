# Run from sim/: vsim -c -do run_questa.do
# UVM_HOME must point to a UVM 1.2 root containing src/uvm_pkg.sv.
onerror {quit -code 1 -force}
onbreak {quit -code 1 -force}
if {![info exists env(UVM_HOME)]} {error "Set UVM_HOME to the UVM 1.2 root first"}
set uvm_src [file join $env(UVM_HOME) src]
vlib work
# Compile source explicitly, avoiding dependency on a simulator's library mapping.
# This testbench does not require UVM DPI features.
vlog -sv +define+UVM_NO_DPI +incdir+$uvm_src $uvm_src/uvm_pkg.sv
vlog -sv +incdir+$uvm_src -cover bcesft -f files.f
vsim -coverage -voptargs=+acc work.tb_top +N_RANDOM=100
run -all
coverage save uart.ucdb
coverage report -details -cvg -file coverage.txt
quit -code 0 -force

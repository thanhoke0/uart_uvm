.PHONY: smoke waves clean
smoke:
	mkdir -p build
	iverilog -g2012 -Wall -s tb_smoke -o build/smoke rtl/uart_tx.sv tests/tb_smoke.sv
	cd build && vvp smoke
waves:
	mkdir -p build
	iverilog -g2012 -Wall -s tb_smoke -o build/smoke rtl/uart_tx.sv tests/tb_smoke.sv
	cd build && vvp smoke +WAVES
clean:
	rm -rf build sim/work sim/transcript sim/vsim.wlf sim/uart.ucdb sim/uart.vcd sim/coverage.txt

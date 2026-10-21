`timescale 1ns/1ps
module tb_top;
  import uvm_pkg::*;
  import uart_pkg::*;
  bit clk = 0;
  always #5 clk = ~clk;
  uart_if vif(clk);
  uart_tx dut(.clk(clk), .rst_n(vif.rst_n), .valid(vif.valid),
    .data(vif.data), .parity_mode(vif.parity_mode), .two_stop(vif.two_stop),
    .clks_per_bit(vif.clks_per_bit), .tx(vif.tx), .ready(vif.ready),
    .busy(vif.busy), .done(vif.done));
  initial begin
    uvm_config_db#(virtual uart_if)::set(null, "*", "vif", vif);
    uvm_top.finish_on_completion=0;
    run_test("uart_test");
    begin
      uvm_report_server server;
      server=uvm_report_server::get_server();
      if (server.get_severity_count(UVM_ERROR)!=0 || server.get_severity_count(UVM_FATAL)!=0)
        $fatal(1,"UVM reported errors");
    end
    $finish;
  end
  initial begin
    $dumpfile("uart.vcd");
    $dumpvars(0, tb_top);
  end
  initial begin
    #100_000_000;
    $fatal(1, "Simulation watchdog expired");
  end
endmodule

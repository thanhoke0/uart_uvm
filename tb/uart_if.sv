`timescale 1ns/1ps
interface uart_if(input logic clk);
  logic rst_n = 0, valid = 0;
  logic [7:0] data = 0;
  logic [1:0] parity_mode = 0;
  logic two_stop = 0;
  logic [15:0] clks_per_bit = 8;
  wire tx, ready, busy, done;
endinterface

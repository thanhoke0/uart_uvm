`timescale 1ns/1ps
// 8-bit UART transmitter. Config is captured only on valid && ready.
module uart_tx (
  input wire clk, rst_n, valid,
  input wire [7:0] data,
  input wire [1:0] parity_mode, // 0:none, 1:even, 2:odd; 3 treated as none
  input wire two_stop,
  input wire [15:0] clks_per_bit, // values below 2 are clamped to 2
  output wire ready,
  output reg tx, busy, done
);
  reg [11:0] frame;
  reg [3:0] index, length;
  reg [15:0] count, divisor;
  reg [11:0] next_frame;
  reg [3:0] next_length;
  always_comb begin
    next_frame = 12'hfff;
    next_frame[0] = 1'b0;
    next_frame[8:1] = data;
    if (parity_mode == 1 || parity_mode == 2) begin
      next_frame[9] = (^data) ^ (parity_mode == 2);
      next_length = two_stop ? 12 : 11;
    end else next_length = two_stop ? 11 : 10;
  end
  assign ready = !busy;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tx <= 1; busy <= 0; done <= 0;
      frame <= 12'hfff; index <= 0; length <= 0;
      count <= 0; divisor <= 2;
    end else begin
      done <= 0;
      if (!busy) begin
        tx <= 1;
        if (valid) begin
          frame <= next_frame; length <= next_length;
          divisor <= (clks_per_bit < 2) ? 16'd2 : clks_per_bit;
          index <= 0; count <= 0; busy <= 1; tx <= 0;
        end
      end else if (count == divisor - 1) begin
        count <= 0;
        if (index == length - 1) begin
          tx <= 1; busy <= 0; done <= 1;
        end else begin
          index <= index + 1'b1;
          tx <= frame[index + 1'b1];
        end
      end else count <= count + 1'b1;
    end
  end
endmodule

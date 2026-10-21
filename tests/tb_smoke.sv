`timescale 1ns/1ps
module tb_smoke;
  reg clk=0, rst_n=0, valid=0;
  reg [7:0] data=0;
  reg [1:0] parity_mode=0;
  reg two_stop=0;
  reg [15:0] clks_per_bit=8;
  wire tx,ready,busy,done;
  integer checked=0, b,p,s,d,k,seed=42,unused;
  uart_tx dut(.*);
  always #5 clk=~clk;
  task send_check(input [7:0] value, input integer mode,
                  input integer stops, input integer cpb,
                  input integer disturb);
    reg [11:0] reference_bits;
    integer nbits, effective_div, bit_no, cycle_no;
    begin
      effective_div=(cpb<2)?2:cpb;
      reference_bits=12'hfff;
      reference_bits[0]=0;
      for(bit_no=0;bit_no<8;bit_no=bit_no+1)
        reference_bits[bit_no+1]=value[bit_no];
      nbits=1+8+stops;
      if(mode==1 || mode==2) begin
        reference_bits[9]=(^value) ^ (mode==2);
        nbits=nbits+1;
      end
      @(negedge clk);
      if(!ready) $fatal(1,"Not ready before request");
      data=value; parity_mode=mode; two_stop=(stops==2);
      clks_per_bit=cpb; valid=1;
      @(posedge clk); #1;
      if(!busy || ready || tx!==0 || done) $fatal(1,"Acceptance failed");
      for(cycle_no=0;cycle_no<nbits*effective_div;cycle_no=cycle_no+1) begin
        @(negedge clk);
        // Every serial cycle is checked, including boundaries and both stop bits.
        if(tx !== reference_bits[cycle_no/effective_div] || !busy || ready || done)
          $fatal(1,"Serial/timing mismatch data=%h mode=%0d stops=%0d div=%0d cycle=%0d tx=%b expected=%b",
            value,mode,stops,cpb,cycle_no,tx,reference_bits[cycle_no/effective_div]);
        valid=0;
        if(disturb && cycle_no==3) begin
          valid=1; data=~value; parity_mode=3; two_stop=~two_stop; clks_per_bit=99;
        end
      end
      @(posedge clk); #1;
      if(busy || !ready || !done || tx!==1) $fatal(1,"Frame duration/done failed");
      @(posedge clk); #1;
      if(done || tx!==1) $fatal(1,"Done must be one cycle, idle must be high");
      checked=checked+1;
    end
  endtask
  initial begin
    if($test$plusargs("WAVES")) begin
      $dumpfile("smoke.vcd"); $dumpvars(0,tb_smoke);
    end
    unused=$value$plusargs("SEED=%d",seed);
    unused=$urandom(seed);
    repeat(3) @(negedge clk);
    if(tx!==1 || busy || done || !ready) $fatal(1,"Reset state failed");
    rst_n=1;
    for(p=0;p<3;p=p+1)
      for(s=1;s<=2;s=s+1)
        for(d=0;d<3;d=d+1)
          for(b=0;b<256;b=b+1)
            send_check(b,p,s,(d==0)?2:((d==1)?8:16),1);
    repeat(100) send_check($urandom,$urandom_range(0,2),$urandom_range(1,2),$urandom_range(2,20),1);
    // Reserved mode is no parity; divisor 0/1 clamps to 2.
    send_check(8'ha5,3,1,0,1);
    send_check(8'h5a,0,2,1,1);
    // Asynchronous reset aborts an active frame and permits recovery.
    @(negedge clk); valid=1; data=0; parity_mode=1; clks_per_bit=8;
    @(negedge clk); valid=0;
    repeat(13) @(negedge clk);
    #2 rst_n=0; #1;
    if(tx!==1 || busy || done || !ready) $fatal(1,"Mid-frame reset failed");
    repeat(3) @(negedge clk);
    rst_n=1;
    send_check(8'h96,2,2,8,0);
    $display("PASS: %0d complete frames; all bytes/formats, busy rejection, config latch, reset recovery",checked);
    $finish;
  end
  initial begin #100_000_000; $fatal(1,"Watchdog timeout"); end
endmodule

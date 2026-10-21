`timescale 1ns/1ps
package uart_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  class uart_item extends uvm_sequence_item;
    rand bit [7:0] data;
    rand bit [1:0] parity_mode;
    rand bit two_stop;
    rand int unsigned divisor;
    rand int unsigned gap;
    bit parity_bit;
    bit framing_ok = 1;
    constraint legal_c {
      parity_mode inside {0,1,2};
      divisor inside {2,8,16};
      gap inside {[0:7]};
    }
    `uvm_object_utils_begin(uart_item)
      `uvm_field_int(data, UVM_ALL_ON)
      `uvm_field_int(parity_mode, UVM_ALL_ON)
      `uvm_field_int(two_stop, UVM_ALL_ON)
      `uvm_field_int(divisor, UVM_ALL_ON)
      `uvm_field_int(gap, UVM_ALL_ON)
      `uvm_field_int(parity_bit, UVM_ALL_ON)
      `uvm_field_int(framing_ok, UVM_ALL_ON)
    `uvm_object_utils_end
    function new(string name="uart_item"); super.new(name); endfunction
  endclass

  class uart_sequence extends uvm_sequence#(uart_item);
    `uvm_object_utils(uart_sequence)
    function new(string name="uart_sequence"); super.new(name); endfunction
    task body();
      uart_item req;
      int divisors[3] = '{2,8,16};
      int n_random = 100;
      void'($value$plusargs("N_RANDOM=%d", n_random));
      // Exhaust all payloads and supported configuration combinations.
      for (int p=0; p<3; p++)
        for (int s=0; s<2; s++)
          foreach (divisors[d])
            for (int b=0; b<256; b++) begin
              req = uart_item::type_id::create("directed");
              start_item(req);
              req.data=b; req.parity_mode=p; req.two_stop=s;
              req.divisor=divisors[d]; req.gap=0;
              finish_item(req);
            end
      repeat(n_random) begin
        req=uart_item::type_id::create("randomized");
        start_item(req);
        if (!req.randomize()) `uvm_fatal("RAND", "Randomization failed")
        finish_item(req);
      end
    endtask
  endclass

  class uart_driver extends uvm_driver#(uart_item);
    `uvm_component_utils(uart_driver)
    virtual uart_if vif;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual uart_if)::get(this,"","vif",vif))
        `uvm_fatal("VIF", "Missing interface")
    endfunction
    task run_phase(uvm_phase phase);
      uart_item req;
      bit completed;
      vif.rst_n=0; vif.valid=0;
      repeat(5) @(negedge vif.clk);
      vif.rst_n=1;
      forever begin
        seq_item_port.get_next_item(req);
        @(negedge vif.clk);
        while (vif.ready !== 1'b1) @(negedge vif.clk);
        vif.data=req.data; vif.parity_mode=req.parity_mode;
        vif.two_stop=req.two_stop; vif.clks_per_bit=req.divisor;
        vif.valid=1;
        @(negedge vif.clk);
        vif.valid=0;
        completed=0;
        repeat(12*req.divisor+4) begin
          @(negedge vif.clk);
          if (vif.done === 1'b1) begin completed=1; break; end
        end
        if (!completed) `uvm_fatal("TIMEOUT", "TX did not complete")
        repeat(req.gap+1) @(negedge vif.clk);
        seq_item_port.item_done();
      end
    endtask
  endclass

  class uart_monitor extends uvm_monitor;
    `uvm_component_utils(uart_monitor)
    virtual uart_if vif;
    uvm_analysis_port#(uart_item) expected_ap, actual_ap;
    function new(string name, uvm_component parent);
      super.new(name,parent);
      expected_ap=new("expected_ap",this); actual_ap=new("actual_ap",this);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual uart_if)::get(this,"","vif",vif))
        `uvm_fatal("VIF", "Missing interface")
    endfunction
    task run_phase(uvm_phase phase);
      uart_item exp, obs;
      forever begin
        // Sample handshake before DUT nonblocking updates.
        @(posedge vif.clk);
        if (vif.rst_n && vif.valid && vif.ready) begin
          exp=uart_item::type_id::create("accepted");
          exp.data=vif.data; exp.parity_mode=vif.parity_mode;
          exp.two_stop=vif.two_stop;
          exp.divisor=(vif.clks_per_bit<2) ? 2 : vif.clks_per_bit;
          expected_ap.write(exp);
          obs=uart_item::type_id::create("decoded");
          obs.parity_mode=exp.parity_mode; obs.two_stop=exp.two_stop;
          obs.divisor=exp.divisor;
          // Decode at bit centers; serial payload never comes from input data.
          repeat(exp.divisor/2) @(negedge vif.clk);
          obs.framing_ok=(vif.tx === 1'b0);
          for (int i=0;i<8;i++) begin
            repeat(exp.divisor) @(negedge vif.clk);
            if ($isunknown(vif.tx)) obs.framing_ok=0;
            obs.data[i]=vif.tx;
          end
          if (exp.parity_mode inside {1,2}) begin
            repeat(exp.divisor) @(negedge vif.clk);
            if ($isunknown(vif.tx)) obs.framing_ok=0;
            obs.parity_bit=vif.tx;
          end
          repeat(exp.two_stop ? 2 : 1) begin
            repeat(exp.divisor) @(negedge vif.clk);
            if (vif.tx !== 1'b1) obs.framing_ok=0;
          end
          actual_ap.write(obs);
        end
      end
    endtask
  endclass

  class uart_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(uart_scoreboard)
    uvm_tlm_analysis_fifo#(uart_item) expected_fifo, actual_fifo;
    int unsigned checked;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      expected_fifo=new("expected_fifo",this); actual_fifo=new("actual_fifo",this);
    endfunction
    task run_phase(uvm_phase phase);
      uart_item exp, obs;
      bit parity;
      forever begin
        expected_fifo.get(exp); actual_fifo.get(obs);
        parity=(^exp.data) ^ (exp.parity_mode==2);
        if (obs.data !== exp.data || !obs.framing_ok ||
            ((exp.parity_mode inside {1,2}) && obs.parity_bit !== parity))
          `uvm_error("MISMATCH", $sformatf("expected=%02h observed=%02h mode=%0d framing_ok=%0b parity=%0b expected_parity=%0b",
            exp.data,obs.data,exp.parity_mode,obs.framing_ok,obs.parity_bit,parity))
        checked++;
      end
    endtask
    function void check_phase(uvm_phase phase);
      int n_random=100;
      super.check_phase(phase);
      void'($value$plusargs("N_RANDOM=%d", n_random));
      if (checked != 4608+n_random)
        `uvm_error("COUNT", $sformatf("Expected %0d frames, checked %0d",4608+n_random,checked))
      if (checked==0 || expected_fifo.used()!=0 || actual_fifo.used()!=0)
        `uvm_error("INCOMPLETE", "No traffic or unmatched transactions remain")
    endfunction
    function void report_phase(uvm_phase phase);
      `uvm_info("RESULT", $sformatf("Checked %0d serial frames; inspect UVM error/fatal counts for pass/fail",checked),UVM_LOW)
    endfunction
  endclass

  class uart_coverage extends uvm_subscriber#(uart_item);
    `uvm_component_utils(uart_coverage)
    covergroup frame_cg with function sample(uart_item t);
      option.per_instance=1;
      payload: coverpoint t.data { bins bytes[]={[0:255]}; }
      parity: coverpoint t.parity_mode { bins none={0}; bins even_p={1}; bins odd_p={2}; }
      stops: coverpoint t.two_stop { bins one={0}; bins two={1}; }
      baud: coverpoint t.divisor { bins fast={2}; bins nominal={8}; bins slow={16}; }
      framing: coverpoint t.framing_ok { bins good={1}; illegal_bins bad={0}; }
      payload_format: cross payload, parity, stops;
      format_baud: cross parity, stops, baud;
    endgroup
    function new(string name, uvm_component parent);
      super.new(name,parent); frame_cg=new();
    endfunction
    function void write(uart_item t); frame_cg.sample(t); endfunction
    function void report_phase(uvm_phase phase);
      `uvm_info("COVERAGE",$sformatf("Functional coverage: %0.2f%%",frame_cg.get_inst_coverage()),UVM_LOW)
    endfunction
  endclass

  class uart_agent extends uvm_agent;
    `uvm_component_utils(uart_agent)
    uvm_sequencer#(uart_item) sequencer;
    uart_driver driver;
    uart_monitor monitor;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      sequencer=new("sequencer",this);
      driver=uart_driver::type_id::create("driver",this);
      monitor=uart_monitor::type_id::create("monitor",this);
    endfunction
    function void connect_phase(uvm_phase phase);
      driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
  endclass

  class uart_env extends uvm_env;
    `uvm_component_utils(uart_env)
    uart_agent agent;
    uart_scoreboard scoreboard;
    uart_coverage coverage;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      agent=uart_agent::type_id::create("agent",this);
      scoreboard=uart_scoreboard::type_id::create("scoreboard",this);
      coverage=uart_coverage::type_id::create("coverage",this);
    endfunction
    function void connect_phase(uvm_phase phase);
      agent.monitor.expected_ap.connect(scoreboard.expected_fifo.analysis_export);
      agent.monitor.actual_ap.connect(scoreboard.actual_fifo.analysis_export);
      agent.monitor.actual_ap.connect(coverage.analysis_export);
    endfunction
  endclass

  class uart_test extends uvm_test;
    `uvm_component_utils(uart_test)
    uart_env env;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase); env=uart_env::type_id::create("env",this);
    endfunction
    task run_phase(uvm_phase phase);
      uart_sequence seq;
      phase.raise_objection(this);
      seq=uart_sequence::type_id::create("seq");
      seq.start(env.agent.sequencer);
      // Driver returns after stop completion; leave time for scoreboard consumption.
      #100;
      phase.drop_objection(this);
    endtask
  endclass
endpackage

class transaction;
  randc bit [1:0] d_in;
  bit [1:0] d_out;
  function transaction copy();
    copy=new();
    copy.d_in=this.d_in;
    copy.d_out=this.d_out;
    return copy;
  endfunction
  
  function void display(input string tag);
    $display("[%0s] DIN : %0d \t DOUT : %0d", tag, d_in, d_out);
  endfunction
endclass

class generator;
  transaction trans;
  mailbox #(transaction) gen2drv;
  mailbox #(transaction) gen2sco;
  event sco_next;
  event gen_done;
  int count;
  
  function new (mailbox #(transaction) gen2drv, mailbox #(transaction) gen2sco);
    this.gen2drv=gen2drv;
    this.gen2sco=gen2sco;
    trans=new();
  endfunction
  
  task run();
    repeat(count) begin
      assert(trans.randomize()) else $error("RANDOMIZATION FAILED");
      gen2drv.put(trans);
      gen2sco.put(trans);
      trans.display("GEN");
      @(sco_next);
    end
    ->gen_done;
  endtask
endclass

class driver;
  transaction trans;
  mailbox #(transaction) gen2drv;
  
  virtual to_dut_interface d_if;
  
  function new (mailbox #(transaction) gen2drv);
    this.gen2drv = gen2drv;
    trans=new();
  endfunction
  
  task reset();
    d_if.rst<=1'b1;
    repeat(5) @(posedge d_if.clk);
    d_if.rst<=1'b0;
    @(posedge d_if.clk);
    $display("[DRV] RESET DONE");
  endtask

  task run();
    forever begin
      gen2drv.get(trans);
      d_if.d_in = trans.d_in;
      @(posedge d_if.clk);
      trans.display("DRV");
      d_if.d_in <= 1'b0;
      @(posedge d_if.clk);
    end
  endtask
endclass

class monitor;
  transaction trans;
  mailbox #(transaction) mon2sco;
  
  virtual to_dut_interface d_if;
  
  function new (mailbox #(transaction) mon2sco);
    this.mon2sco = mon2sco;
  endfunction
  
  task run();
    trans=new();
    forever begin
      repeat(2) @(posedge d_if.clk)
      trans.d_out = d_if.d_out;
      mon2sco.put(trans);
      trans.display("MON");
    end
  endtask
endclass
  
class scoreboard;
  transaction trans_from_gen;
  transaction trans_from_mon;
  
  mailbox #(transaction) gen2sco;
  mailbox #(transaction) mon2sco;
  
  event sco_next;
  
  function new(mailbox #(transaction) mon2sco, mailbox #(transaction) gen2sco);
    this.gen2sco = gen2sco;
    this.mon2sco = mon2sco;
  endfunction
  
  task run();
    forever begin
    gen2sco.get(trans_from_gen);
    mon2sco.get(trans_from_mon);
    trans_from_mon.display("SCO");
    trans_from_gen.display("REF");
    if(trans_from_gen.d_in == trans_from_mon.d_out)
      $display("[SCO] DATA MATCH ");
    else
      $display("[SCO] DATA MIS-MATCH ");
    ->sco_next;
    end
  endtask
endclass

class environment;
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  
  mailbox #(transaction) mon2sco;
  mailbox #(transaction) gen2drv;
  mailbox #(transaction) gen2sco;
  
  virtual to_dut_interface d_if;
  
  event next;
  
  function new(virtual to_dut_interface d_if);
    
    gen2drv = new();
    gen2sco = new();
    gen = new(gen2drv, gen2sco);
    drv = new(gen2drv);
    
    mon2sco = new();
    mon = new(mon2sco);
    sco = new(mon2sco, gen2sco);
    
    drv.d_if = d_if;
    mon.d_if = d_if;
    
    gen.sco_next = next;
    sco.sco_next = next;
    
  endfunction
  
  task pre_test();
    drv.reset();
  endtask
  
  task test();
    fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_any
  endtask
  
  task post_test;
    wait(gen.gen_done.triggered);
    $finish();
  endtask
  
  task run();
    pre_test();
    test();
    post_test();
  endtask
endclass

module top;
  environment env;
  
  to_dut_interface d_if();
  D_FF dut(d_if);
  
  initial begin
    d_if.clk<=0;
  end
  always #10 d_if.clk<=~d_if.clk;
  
  initial begin
    env=new(d_if);
    env.gen.count = 30;
    env.run(); 
  end
  
  initial begin
    $dumpfile("dump.vcd"); // Specify the VCD dump file
    $dumpvars; // Dump all variables
  end
endmodule

////////////////
<<<<<<< HEAD
    initial begin
        $display("My changes");
        $display("Incoming changes");
    end
>>>>>>> deb1824 (D-ff Layered TB)

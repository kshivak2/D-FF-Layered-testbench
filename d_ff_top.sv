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


class transaction;
  rand bit op;
  bit [7:0] din;
  bit [7:0] dout;
  bit empty;
  bit full;
  bit rd, wr;
  
  constraint open_ctrl{
    op dist{1:/50, 0:/50};
  }
endclass

class generator;
  transaction trans;
  mailbox #(transaction) gen2drv;
  
  event next;
  event done;
  
  function new(mailbox #(transaction) gen2drv);
    this.gen2drv = gen2drv;
    trans = new();
  endfunction
  
  
  task run();
  int count = 0;
  int i = 0;
  
  repeat(count) begin
    i++;
    assert(trans.randomize()) else $error("RANDOMIZATION FAILED");
    gen2drv.put(trans);
    $display("[GEN] OP : %0d \t ITERATION : %0d", trans.op, i);
    @(next);
  end
  
  ->done;
  endtask
endclass

class driver;
  transaction trans;
  mailbox #(transaction) gen2drv;
  virtual fifo f;
  
  function new(mailbox #(transaction) gen2drv);
    this.gen2drv=gen2drv;
  endfunction
  
  task reset();
    f.rst <= 1;
    f.rd <= 0;
    f.wr <= 0;
    f.din <= 0;
    repeat(5) @(posedge f.clk);
    $display("[DRV] RESET DONE");
    f.rst <= 0;
  endtask
  
  task write();
    @(posedge f.clk);
    f.rst <= 0;
    f.wr <= 1;
    f.rd <= 0;
    @(posedge f.clk);
    f.din <= $urandom_rande(1,10);
    $display("[DRV] DATA WRITTEN : %0d", f.din);
    f.wr <= 0;
    @(posedge f.clk);
  endtask
  
  task read();
    @(posedge f.clk);
    f.rst <= 0;
    f.wr <= 0;
    f.rd <= 1;
    @(posedge f.clk);
    $display("[DRV] DATA READ"); 
    f.rd <= 0;
    @(posedge f.clk);
  endtask
  
  task run();
    forever begin
    gen2drv.get(trans);
    if(trans.op == 1) write();
    else read();
    end
  endtask
endclass
    
class monitor;
  transaction trans;
  virtual fifo f;
  mailbox mon2sco;
  
  function new(mailbox #(transaction));
    this.mon2sco = mon2sco;
    trans = new();
  endfunction
  
  task run();
    trans = new(); // TODO: add this inside custom constructor and see how it affects
    forever begin
      repeat(2) @(posedge f.clk);
      trans.wr <= f.wr;
      trans.rd <= f.rd;
      trans.din <= f.din;
      trans.empty <= f.empty;
      trans.full <= f.full;
      @(posedge f.clk);
      trans.dout <= f.dout;
      mon2sco.put(trans);
      $display("[MON] : Wr:%0d rd:%0d din:%0d dout:%0d full:%0d empty:%0d", trans.wr, trans.rd,          		 trans.din, trans.dout, trans.full, trans.empty);
    end
  endtask
endclass

class scoreboard;
  transaction trans;
  mailbox #(transaction) mon2sco;
  
  bit [7:0] din[$];
  bit err = 0;
  
  function new(mailbox #(transaction));
    this.mon2sco = mon2sco;
  endfunction
  
  task run();
    forever begin
      mon2sco.get(trans);
      $display("[SCO] : Wr:%0d rd:%0d din:%0d dout:%0d full:%0d empty:%0d", trans.wr, trans.rd, 			trans.din, trans.dout, trans.full, trans.empty);
      
      if(trans.wr == 1'b1) begin
        if(trans.full == 1'b0) begin
          din.push_front(trans.din);
          $display("[SCO] DATA STORED IN QUEUE : %0d", trans.din);
        end
        else begin
          $display("[SCO] FIFO is FUL");
        end
      end
      else if (trans.rd == 1'b1) begin
        if(trans.empty == 1'b0) begin
          temp = din.pop_back();
          
          if(trans.dout == temp) begin
            $display("[SCO] DATA MATCH");
          end
          else begin
            $display("[SCO] DATA MIS-MATCH");
            err++;
          end
        end
        else begin
          $display("[SCO] FIFO IS EMPTY");
        end
      end
      ->next;
    end
  endtask
endclass
      
class environment;
  generator gen;
  driver drv;
  montior mon;
  scoreboard sco;
  
  mailbox #(transaction) gen2drv;
  mailbox #(transaction) mon2sco;
  
  event next_env;
  
  virtual fifo f;
  
  function new(virtual fifo f);
    gen2drv = new();
    mon2sco = new();
    gen = (gen2drv);
    drv = (gen2drv);
    mon = (mon2sco);
    sco = (mon2sco);
    
    this.f = f;
    drv.f = this.f;
    mon.f = this.f;
    
    gen.next = next_env;
    sco.next = next_env;
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
  
  task post_test();
    wait(gen.done.triggered());
    $display("---------------------------------------------");
    $display("Error Count :%0d", sco.err);
    $display("---------------------------------------------");
    $finish;
  endtask
  
  task run();
    pre_test();
    test();
    post_test();
  endtask
endclass

module tb;
  fifo f();
  FIFO dut(.din(f.din)
      
  
  
  
    
    
  
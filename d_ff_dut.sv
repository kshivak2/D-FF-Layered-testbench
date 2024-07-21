
module D_FF (to_dut_interface d_if);
  always@(posedge d_if.clk) begin
    if(d_if.rst == 1'b1)
      d_if.d_out <= 1'b0;
    else
      d_if.d_out<=d_if.d_in;
  end
endmodule

interface to_dut_interface;
  logic [1:0] d_in;
  logic [1:0] d_out;
  logic clk;
  logic rst;
endinterface
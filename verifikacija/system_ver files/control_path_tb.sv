`timescale 1ns / 1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

`include "control_path_if.sv"
`include "control_path_test.sv"

module control_path_tb;

  logic clk;
  control_path_if vif(clk);

  // Clock
  initial begin
    clk = 0;
    forever #10 clk = ~clk;
  end
  
  //reset
  initial begin
      vif.reset = 1;
      repeat (5) @(posedge clk);
      vif.reset = 0;
  end


  // UVM interface
  initial begin
    uvm_config_db#(virtual control_path_if)::set(null, "*", "vif", vif);
    run_test("control_path_test");
  end

  // DUT
  control_path dut (
    .clk              (vif.clk),
    .reset            (vif.reset),
    .start            (vif.start),
    .ready            (vif.ready),
    .rows_in          (vif.rows_in),
    .cols_in          (vif.cols_in),
    .lower_in         (vif.lower_in),
    .upper_in         (vif.upper_in),
    .bram1_en         (vif.bram1_en),
    .bram1_we         (vif.bram1_we),
    .bram1_addr       (vif.bram1_addr),
    .bram1_indata     (vif.bram1_indata),
    .bram1_outdata    (vif.bram1_outdata),
    .bram2_en         (vif.bram2_en),
    .bram2_we         (vif.bram2_we),
    .bram2_addr       (vif.bram2_addr),
    .bram2_indata     (vif.bram2_indata),
    .bram2_outdata    (vif.bram2_outdata),
    .objects_count_out(vif.objects_count_out)
  );

endmodule

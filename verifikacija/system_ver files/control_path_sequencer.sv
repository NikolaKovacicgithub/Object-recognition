`ifndef CONTROL_PATH_SEQUENCER_SV
`define CONTROL_PATH_SEQUENCER_SV

`include "uvm_macros.svh"
import uvm_pkg::*;
`include "control_path_txn.sv"

class control_path_sequencer extends uvm_sequencer #(control_path_txn);
  `uvm_component_utils(control_path_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass

`endif

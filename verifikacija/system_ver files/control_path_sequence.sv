// control_path_sequence.sv
`ifndef CONTROL_PATH_SEQUENCE_SV
`define CONTROL_PATH_SEQUENCE_SV
`include "uvm_macros.svh"
import uvm_pkg::*;
`include "control_path_txn.sv"

class control_path_sequence extends uvm_sequence #(control_path_txn);
  `uvm_object_utils(control_path_sequence)
  control_path_txn tr;

  function new(string name="control_path_sequence");
    super.new(name);
  endfunction

  task body();
    if (tr == null)
      `uvm_fatal(get_type_name(), "Transakcija 'tr' nije prosleđena sekvenci!")
    tr.expected_objects = 1;
    start_item(tr);
    finish_item(tr);
  endtask
endclass
`endif

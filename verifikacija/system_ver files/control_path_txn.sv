`ifndef CONTROL_PATH_TXN_SV
`define CONTROL_PATH_TXN_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

class control_path_txn extends uvm_sequence_item;

  // Ulazni signali
  rand bit [5:0] rows_in, cols_in;
  rand bit [23:0] lower_in, upper_in;
  rand bit start;

  // Ulazna slika (piksela)
  rand bit [23:0] image_data[];       

  // Scoreboard poređenje
  rand bit [4:0] expected_objects;    // setuje se u sequence-u
       bit [4:0] result_objects;      // dolazi iz monitora (vif.objects_count_out)

  `uvm_object_utils(control_path_txn)

  function new(string name = "control_path_txn");
    super.new(name);
  endfunction

endclass

`endif

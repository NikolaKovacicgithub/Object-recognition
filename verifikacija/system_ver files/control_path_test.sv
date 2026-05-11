`ifndef CONTROL_PATH_TEST_SV
`define CONTROL_PATH_TEST_SV

`include "uvm_macros.svh"
import uvm_pkg::*;
`include "control_path_test_base.sv"

// minimalni single-shot sequence
`include "control_path_sequence.sv"

// koristi SAMO prvu sliku
`include "image_data.svh"   // bit [23:0] image_data [0:3720]

class control_path_test extends control_path_test_base;
  `uvm_component_utils(control_path_test)

  int expected = 1;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db#(int)::set(this, "*", "expected_objects", expected);
  endfunction

  task run_phase(uvm_phase phase);
    control_path_sequence seq = control_path_sequence::type_id::create("seq");
    seq.tr = control_path_txn::type_id::create("tr");

    // parametri za PRVU sliku
    seq.tr.rows_in = 61;
    seq.tr.cols_in = 61;
    seq.tr.lower_in = 24'hB45A32;  // low za sliku 1
    seq.tr.upper_in = 24'hFF8246;  // high za sliku 1
    seq.tr.expected_objects = expected;

    // sama slika
    seq.tr.image_data = new[3721];
    for (int i = 0; i < 3721; i++) seq.tr.image_data[i] = image_data[i];

    phase.raise_objection(this);
      `uvm_info(get_type_name(), "TEST (single image): start", UVM_LOW)
      seq.start(env.seqr);
      #12_000_000ns;
    phase.drop_objection(this);
  endtask
endclass

`endif

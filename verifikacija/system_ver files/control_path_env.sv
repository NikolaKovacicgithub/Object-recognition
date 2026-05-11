`ifndef CONTROL_PATH_ENV_SV
`define CONTROL_PATH_ENV_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

`include "control_path_txn.sv"
`include "control_path_driver.sv"
`include "control_path_sequencer.sv"
`include "control_path_monitor.sv"
`include "control_path_scoreboard.sv"

class control_path_env extends uvm_env;
  `uvm_component_utils(control_path_env)

  control_path_sequencer seqr;
  control_path_driver    driv;
  control_path_monitor   mon;
  control_path_scoreboard sb;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    seqr = control_path_sequencer::type_id::create("seqr", this);
    driv = control_path_driver::type_id::create("driv", this);
    mon  = control_path_monitor::type_id::create("mon", this);
    sb   = control_path_scoreboard::type_id::create("sb", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    driv.seq_item_port.connect(seqr.seq_item_export); // sequencer → driver
    mon.ap.connect(sb.sb_port);                       // monitor → scoreboard
  endfunction

endclass

`endif

`ifndef CONTROL_PATH_TEST_BASE_SV
`define CONTROL_PATH_TEST_BASE_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

`include "control_path_env.sv"

class control_path_test_base extends uvm_test;
  `uvm_component_utils(control_path_test_base)

  control_path_env env;
  virtual control_path_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    env = control_path_env::type_id::create("env", this);

    // Prosledi virtual interface svim komponentama
    if (!uvm_config_db#(virtual control_path_if)::get(null, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "Nije prosleđen virtual interface kroz config_db")
    end

    uvm_config_db#(virtual control_path_if)::set(this, "env.driv", "vif", vif);
    uvm_config_db#(virtual control_path_if)::set(this, "env.mon", "vif", vif);
  endfunction

endclass

`endif

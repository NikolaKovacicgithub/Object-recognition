`ifndef CONTROL_PATH_SCOREBOARD_SV
`define CONTROL_PATH_SCOREBOARD_SV

`include "uvm_macros.svh"
import uvm_pkg::*;
`include "control_path_txn.sv"

class control_path_scoreboard extends uvm_component;
  `uvm_component_utils(control_path_scoreboard)

  uvm_analysis_imp #(control_path_txn, control_path_scoreboard) sb_port;

  int total_tests;
  int passed_tests;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    sb_port = new("sb_port", this);
    total_tests = 0;
    passed_tests = 0;
  endfunction

  // Obrada pristigle transakcije iz monitora
  function void write(control_path_txn tr);
    total_tests++;

    `uvm_info(get_type_name(),
      $sformatf("SCOREBOARD: Expected = %0d, DUT Result = %0d",
                tr.expected_objects, tr.result_objects),
      UVM_LOW)

    // Poređenje rezultata
    if (tr.result_objects !== tr.expected_objects) begin
      `uvm_error(get_type_name(),
        $sformatf("Mismatch: Expected %0d, Got %0d",
                  tr.expected_objects, tr.result_objects))
    end else begin
      `uvm_info(get_type_name(),
        $sformatf("Match: Expected = Got = %0d", tr.expected_objects),
        UVM_LOW)
      passed_tests++;
    end
  endfunction

  // Završni izveštaj
  function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
      $sformatf("Scoreboard report: Passed %0d / %0d tests",
                passed_tests, total_tests),
      UVM_NONE)
  endfunction

endclass

`endif

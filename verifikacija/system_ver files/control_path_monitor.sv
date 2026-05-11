`ifndef CONTROL_PATH_MONITOR_SV
`define CONTROL_PATH_MONITOR_SV

`include "uvm_macros.svh"
import uvm_pkg::*;
`include "control_path_txn.sv"

class control_path_monitor extends uvm_monitor;
  `uvm_component_utils(control_path_monitor)

  // Virtuelni interfejs
  virtual control_path_if vif;

  //Pport ka scoreboard-u
  uvm_analysis_port #(control_path_txn) ap;

  //Očekivana vrednost iz config_db
  int expected_objects;

  // MIRROR polja za coverage
  logic [23:0] s_lower, s_upper;  // korišćen opseg
  logic [4:0]  s_objs;            // rezultat DUT-a (broj objekata)

  // BRAM mirrori
  logic [1:0]  s_port;            // {bram2_en, bram1_en}
  logic        s_rw;              // 0=read, 1=write
  logic [11:0] s_addr;            // adresa

  // handshake mirrori
  logic        s_start, s_ready;

  // --- ID izabranog opsega 0 ili 1 ili -1 ako nije iz liste
  int obj_id;

  // Tvoja DVA opsega (LOWER/UPPER)
  localparam int N_OPS = 2;
  localparam bit [23:0] L_LIST [N_OPS] = '{ 24'hB45A32, 24'h648750 }; // img0, img1
  localparam bit [23:0] U_LIST [N_OPS] = '{ 24'hFF8246, 24'h87C88C }; // img0, img1

  function int pick_id(bit [23:0] lo, bit [23:0] up);
    for (int i = 0; i < N_OPS; i++) begin
      if (lo == L_LIST[i] && up == U_LIST[i]) return i;
    end
    return -1;
  endfunction

  // 1) Funkcionalna pokrivenost: SAMO opseg za sliku 1 + rezultat
  covergroup cov_res;
    option.per_instance = 1;
    option.goal = 100;

    // uzorkuj samo ako je baš taj par pragova
    cp_lower : coverpoint s_lower iff (s_lower == 24'hB45A32) {
      bins img0 = {24'hB45A32};
    }
    cp_upper : coverpoint s_upper iff (s_upper == 24'hFF8246) {
      bins img0 = {24'hFF8246};
    }

    // očekuje se 1 objekat
    cp_objs : coverpoint s_objs iff (s_objs == 1) {
      bins one = {1};
    }

    // opcioni cross - potvrdi da je korišćen baš taj par + rezultat
    cx_thr_obj : cross cp_lower, cp_upper, cp_objs;
  endgroup

  // 2) BRAM aktivnosti
  covergroup cov_bram;
    option.per_instance = 1;

    cp_port : coverpoint s_port iff (s_port != 2'b00) {
      bins p1 = {2'b01}; // bram1
      bins p2 = {2'b10}; // bram2
    }

    cp_rw : coverpoint s_rw iff (s_port != 2'b00) {
      bins rd = {1'b0};
      bins wr = {1'b1};
    }

    cp_addr : coverpoint s_addr iff (s_port != 2'b00) {
      bins first = {12'd0};
      bins last  = {12'd3720};                // 61*61 - 1
      bins low   = {[12'd1:12'd255]};
      bins mid   = {[12'd256:12'd2047]};
      bins high  = {[12'd2048:12'd3719]};
    }

    cx_bram : cross cp_port, cp_rw, cp_addr;
  endgroup

  // 3) Handshake start/ready
  covergroup cov_hs;
    option.per_instance = 1;
    cp_start : coverpoint s_start { bins pulse = {1}; }
    cp_ready : coverpoint s_ready { bins pulse = {1}; }
    cx_hs    : cross cp_start, cp_ready;
  endgroup

  // Konstruktor
  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);

    cov_res  = new();
    cov_bram = new();
    cov_hs   = new();
  endfunction

  // build_phase: povuci vif/expected iz config_db
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(virtual control_path_if)::get(this, "*", "vif", vif)) begin
      `uvm_fatal("NOVIF", "monitor: no virtual interface provided via config DB")
    end

    if (!uvm_config_db#(int)::get(this, "*", "expected_objects", expected_objects)) begin
      `uvm_fatal("NOEXP", "monitor: expected_objects not provided via config DB")
    end
  endfunction

  // run_phase
  task run_phase(uvm_phase phase);
    control_path_txn tr;

    // (A) BRAM coverage uzorkuj na svaki clk kada je neki en=1
    fork
      forever begin
        @(posedge vif.clk);
        if (vif.bram1_en || vif.bram2_en) begin
          s_port = {vif.bram2_en, vif.bram1_en};
          s_rw   = ((vif.bram1_en && vif.bram1_we) || (vif.bram2_en && vif.bram2_we));
          s_addr = (vif.bram1_en) ? vif.bram1_addr : vif.bram2_addr;
          cov_bram.sample();
        end
      end
    join_none

    // (B) Handshake coverage
    fork
      forever begin
        @(posedge vif.clk);
        s_start = vif.start;
        s_ready = vif.ready;
        cov_hs.sample();
      end
    join_none

    // (C) Funkcionalni tok
    forever begin
      @(posedge vif.clk);
      if (vif.start == 1'b1) begin
        // Snapshot ulaza na start
        tr = control_path_txn::type_id::create("tr", this);
        tr.rows_in  = vif.rows_in;
        tr.cols_in  = vif.cols_in;
        tr.lower_in = vif.lower_in;
        tr.upper_in = vif.upper_in;

        // Čekaj kraj
        @(posedge vif.ready);

        // Popuni mirror-e
        s_lower = tr.lower_in;
        s_upper = tr.upper_in;
        s_objs  = vif.objects_count_out;
        obj_id  = pick_id(s_lower, s_upper);

        // Uzorkuj funkcionalnu pokrivenost
        cov_res.sample();

        // Pošalji rezultat na scoreboard
        tr.result_objects   = vif.objects_count_out;
        tr.expected_objects = expected_objects;
        ap.write(tr);

        `uvm_info(get_type_name(),
          $sformatf("MON: obj_id=%0d lower=0x%06h upper=0x%06h, objects=%0d",
                    obj_id, s_lower, s_upper, tr.result_objects),
          UVM_LOW)
      end
    end
  endtask

endclass

`endif

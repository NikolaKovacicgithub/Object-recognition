`ifndef CONTROL_PATH_DRIVER_SV
`define CONTROL_PATH_DRIVER_SV

`include "uvm_macros.svh"

import uvm_pkg::*;
`include "control_path_txn.sv"
`include "control_path_sequencer.sv"

class control_path_driver extends uvm_driver #(control_path_txn);
  `uvm_component_utils(control_path_driver)

  // Virtuelni interfejs ka DUT-u
  virtual control_path_if vif;

  // Jednostavan model dve memorije
  localparam int MEM_DEPTH = 4096;
  bit [23:0] mem1 [0:MEM_DEPTH-1];  // ulazna slika + radni buffer
  bit [23:0] mem2 [0:MEM_DEPTH-1];  // maska / dodatni buffer

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Preuzmi interfejs iz config DB
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual control_path_if)::get(this, "*", "vif", vif)) begin
      `uvm_fatal("NOVIF", "virtual interface control_path_if must be set")
    end
  endfunction

  // preload slike u mem1
  task preload_image(ref control_path_txn tr);
    int n = tr.image_data.size();
    if (n == 0) begin
      `uvm_warning(get_type_name(), "image_data is empty; mem1 will remain zeroed")
      return;
    end
    if (n > MEM_DEPTH) begin
      `uvm_error(get_type_name(), $sformatf("image_data size %0d exceeds MEM_DEPTH %0d", n, MEM_DEPTH))
      n = MEM_DEPTH;
    end
    for (int i = 0; i < n; i++) begin
      mem1[i] = tr.image_data[i];
    end
    // ostatak očisti
    for (int i = n; i < MEM_DEPTH; i++) begin
      mem1[i] = '0;
    end
    // mem2 očisti
    for (int i = 0; i < MEM_DEPTH; i++) begin
      mem2[i] = '0;
    end
    `uvm_info(get_type_name(),
      $sformatf("Preloaded %0d pixels into mem1", n),
      UVM_LOW)
  endtask

  // Brz brojač piksela u opsegu (RGB)
  function int count_in_range(ref bit [23:0] img[],
                              bit [23:0] low, bit [23:0] up);
    int cnt = 0;
    int n   = img.size();

    bit [7:0] r_l = low[23:16], g_l = low[15:8], b_l = low[7:0];
    bit [7:0] r_u = up[23:16],  g_u = up[15:8],  b_u = up[7:0];

    for (int i = 0; i < n; i++) begin
      bit [7:0] r = img[i][23:16];
      bit [7:0] g = img[i][15:8];
      bit [7:0] b = img[i][7:0];
      if (r >= r_l && r <= r_u &&
          g >= g_l && g <= g_u &&
          b >= b_l && b <= b_u) cnt++;
    end
    return cnt;
  endfunction

  // Soft reset DUT-a između slika
  task do_soft_reset();
    `uvm_info(get_type_name(), "Issuing soft reset between images", UVM_LOW)
    vif.reset <= 1'b1;
    repeat (5) @(posedge vif.clk);
    vif.reset <= 1'b0;
    repeat (2) @(posedge vif.clk);
  endtask

  //  ulaz i  start
  task program_inputs(ref control_path_txn tr);
    // Dimenzije i pragovi
    vif.rows_in  <= tr.rows_in;
    vif.cols_in  <= tr.cols_in;
    vif.lower_in <= tr.lower_in;
    vif.upper_in <= tr.upper_in;

    // Sačekaj dok reset ne padne
    wait (vif.reset == 0);
    
    // Dodatna stabilizacija
    @(posedge vif.clk);
    @(posedge vif.clk);
    
    // Puls start
    vif.start <= 1'b1;
    @(posedge vif.clk);
    vif.start <= 1'b0;

    `uvm_info(get_type_name(),
      $sformatf("Applied rows=%0d cols=%0d lower=0x%06h upper=0x%06h (start pulsed)",
                tr.rows_in, tr.cols_in, tr.lower_in, tr.upper_in),
      UVM_LOW)
  endtask

  // Pozadinski model BRAM-a
  task bram_model();
    // inicijalne vrednosti na TB-vođenim linijama (indata)
    vif.bram1_indata <= '0;
    vif.bram2_indata <= '0;

    forever begin
      @(posedge vif.clk);

      // BRAM1
      if (vif.bram1_en) begin
        if (vif.bram1_we) begin
          // DUT piše u BRAM1
          mem1[vif.bram1_addr] = vif.bram1_outdata;
        end else begin
          // DUT čita iz BRAM1
          vif.bram1_indata <= mem1[vif.bram1_addr];
        end
      end

      // BRAM2
      if (vif.bram2_en) begin
        if (vif.bram2_we) begin
          // DUT piše u BRAM2
          mem2[vif.bram2_addr] = vif.bram2_outdata;
        end else begin
          // DUT čita iz BRAM2
          vif.bram2_indata <= mem2[vif.bram2_addr];
        end
      end
    end
  endtask

  // Čekanje završetka
  task wait_done(ref control_path_txn tr);
    int max_cycles;

    // rows*cols kao trajanje
    max_cycles = (int'(tr.rows_in) * int'(tr.cols_in));
    if (max_cycles < 1) max_cycles = 1;
    // dovoljno vremena za sve faze (maska, dilatacija, kopija, kontura …)
    max_cycles = max_cycles * 300;

    if (^vif.ready !== 1'bx) begin : USE_READY
      // ako je 'ready'  čekaj ga
      int guard = max_cycles;
      while ((vif.ready !== 1'b1) && guard > 0) begin
        @(posedge vif.clk);
        guard--;
      end
      if (guard == 0) begin
        `uvm_warning(get_type_name(),
          $sformatf("Timeout while waiting for ready after %0d cycles; still waiting to avoid overlap", max_cycles))
        // posle timeout-a ipak sačekaj ready da se transakcije ne preklapaju
        wait (vif.ready == 1'b1);
      end else begin
        `uvm_info(get_type_name(), "DUT asserted ready=1", UVM_LOW)
      end
    end else begin : NO_READY
      repeat (max_cycles) @(posedge vif.clk);
      `uvm_warning(get_type_name(),
        $sformatf("No 'ready' signal in interface; advanced by %0d cycles as fallback", max_cycles))
    end

    `uvm_info(get_type_name(),
      $sformatf("objects_count_out = %0d", vif.objects_count_out),
      UVM_LOW)
  endtask

  // primi transakciju
  task main_phase(uvm_phase phase);
  int inrng;
    // default reset stanja ulaza
    vif.start   <= 1'b0;
    vif.rows_in <= '0;
    vif.cols_in <= '0;
    vif.lower_in<= '0;
    vif.upper_in<= '0;

    // pokreni pozadinski BRAM model
    fork
      bram_model();
    join_none

    forever begin
      seq_item_port.get_next_item(req);

      `uvm_info(get_type_name(),
        $sformatf("Driver got txn: rows=%0d cols=%0d img_len=%0d",
                  req.rows_in, req.cols_in, req.image_data.size()),
        UVM_MEDIUM)

      preload_image(req);

      //koliko piksela upada u opseg?
      
      inrng = count_in_range(req.image_data, req.lower_in, req.upper_in);
      `uvm_info(get_type_name(),
        $sformatf("Quick check: pixels in range = %0d (lower=0x%06h upper=0x%06h)",
                  inrng, req.lower_in, req.upper_in),
        UVM_MEDIUM)

      //reset između slika da rezultat bude per-slika (1 + 1)
      do_soft_reset();

      program_inputs(req);
      wait_done(req);

      seq_item_port.item_done();
    end
  endtask

endclass

`endif

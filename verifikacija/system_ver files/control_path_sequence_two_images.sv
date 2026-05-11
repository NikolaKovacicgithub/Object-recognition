// control_path_sequence_two_images.sv
`include "uvm_macros.svh"
import uvm_pkg::*;
`include "control_path_txn.sv"

`include "image_data.svh"

class control_path_sequence_two_images extends uvm_sequence #(control_path_txn);
  `uvm_object_utils(control_path_sequence_two_images)

  // k=0 -> image_data (slika 1)
  // k=1 -> image1_data (slika 2)
  localparam bit [23:0] LOWER [2] = '{
    24'hB45A32, // slika 1
    24'h648750  // slika 2
  };
  localparam bit [23:0] UPPER [2] = '{
    24'hFF8246, // slika 1
    24'h87C88C  // slika 2
  };

  function new(string name="control_path_sequence_two_images");
    super.new(name);
  endfunction

  task body();
    for (int k = 0; k < 2; k++) begin
      control_path_txn tr = control_path_txn::type_id::create($sformatf("tr_img%0d", k), , get_full_name());

      tr.rows_in = 61;
      tr.cols_in = 61;
      tr.lower_in = LOWER[k];
      tr.upper_in = UPPER[k];
      tr.expected_objects = 1; // po slici očekuješ 1 objekat

      tr.image_data = new[3721];
      if (k == 0) begin
        for (int i = 0; i < 3721; i++) tr.image_data[i] = image_data[i];
      end else begin
        for (int i = 0; i < 3721; i++) tr.image_data[i] = image1_data[i];
      end

      start_item(tr);
      finish_item(tr);
    end
  endtask
endclass

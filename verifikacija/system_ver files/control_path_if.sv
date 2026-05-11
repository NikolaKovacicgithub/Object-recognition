`ifndef CONTROL_PATH_IF_SV
`define CONTROL_PATH_IF_SV

interface control_path_if(input logic clk);

  logic reset;
  logic start;
  logic ready;
  logic [5:0] rows_in, cols_in;
  logic [23:0] lower_in, upper_in;
  logic [4:0] objects_count_out;

  logic bram1_en, bram1_we;
  logic [11:0] bram1_addr;
  logic [23:0] bram1_indata, bram1_outdata;

  logic bram2_en, bram2_we;
  logic [11:0] bram2_addr;
  logic [23:0] bram2_indata, bram2_outdata;

endinterface

`endif

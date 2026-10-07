interface gmc_if(input logic clk);
  logic rst_n;

  logic host_valid;
  logic host_ready;
  logic host_write;
  logic [7:0] host_addr;
  logic [31:0] host_wdata;
  logic host_rvalid;
  logic [31:0] host_rdata;

  logic gpu_cmd_valid;
  logic gpu_cmd_ready;
  logic [7:0] gpu_cmd_opcode;
  logic [15:0] gpu_cmd_job_id;
  logic gpu_busy;
  logic gpu_done;
  logic gpu_error;
  logic irq;

  clocking host_cb @(negedge clk);
    output host_valid, host_write, host_addr, host_wdata;
    input host_ready, host_rvalid, host_rdata;
  endclocking
endinterface

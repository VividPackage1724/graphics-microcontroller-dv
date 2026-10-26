interface mc_if(input logic clk);
  logic rst_n;
  logic job_valid;
  logic job_ready;
  logic [7:0] job_opcode;
  logic [15:0] job_id;
  logic gpu_cmd_valid;
  logic gpu_cmd_ready;
  logic [7:0] gpu_cmd_opcode;
  logic [15:0] gpu_cmd_job_id;
  logic exec_done;
  logic exec_error;
  logic completion_valid;
  logic [15:0] completion_job_id;
  logic completion_status;
  logic interrupt_ack;
  logic interrupt;

  // Testbench control for applying downstream backpressure.
  logic ready_enable;
endinterface

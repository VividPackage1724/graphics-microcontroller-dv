module tb_top;
  import uvm_pkg::*;
  import mc_uvm_pkg::*;

  bit clk = 0;
  always #5 clk = ~clk;

  mc_if vif(clk);

  graphics_microcontroller dut (
    .clk(clk), .rst_n(vif.rst_n),
    .job_valid(vif.job_valid), .job_ready(vif.job_ready),
    .job_opcode(vif.job_opcode), .job_id(vif.job_id),
    .gpu_cmd_valid(vif.gpu_cmd_valid), .gpu_cmd_ready(vif.gpu_cmd_ready),
    .gpu_cmd_opcode(vif.gpu_cmd_opcode), .gpu_cmd_job_id(vif.gpu_cmd_job_id),
    .exec_done(vif.exec_done), .exec_error(vif.exec_error),
    .completion_valid(vif.completion_valid), .completion_job_id(vif.completion_job_id),
    .completion_status(vif.completion_status),
    .interrupt_ack(vif.interrupt_ack), .interrupt(vif.interrupt)
  );

  mock_execution_engine #(.LATENCY(3)) mock_engine (
    .clk(clk), .rst_n(vif.rst_n), .ready_enable(vif.ready_enable),
    .gpu_cmd_valid(vif.gpu_cmd_valid), .gpu_cmd_ready(vif.gpu_cmd_ready),
    .gpu_cmd_opcode(vif.gpu_cmd_opcode), .gpu_cmd_job_id(vif.gpu_cmd_job_id),
    .exec_done(vif.exec_done), .exec_error(vif.exec_error)
  );

  initial begin
    vif.rst_n = 0;
    vif.job_valid = 0;
    vif.job_opcode = 0;
    vif.job_id = 0;
    vif.ready_enable = 0;
    vif.interrupt_ack = 0;
    repeat (4) @(negedge clk);
    vif.rst_n = 1;
  end

  initial begin
    uvm_config_db#(virtual mc_if)::set(null, "*", "vif", vif);
    run_test();
  end
endmodule

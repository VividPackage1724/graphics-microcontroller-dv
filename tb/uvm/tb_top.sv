`timescale 1ns/1ps

module tb_top;
  import uvm_pkg::*;
  import gmc_uvm_pkg::*;

  bit clk = 0;
  always #5 clk = ~clk;

  gmc_if vif(clk);

  graphics_microcontroller dut (
    .clk(clk),
    .rst_n(vif.rst_n),
    .host_valid(vif.host_valid),
    .host_ready(vif.host_ready),
    .host_write(vif.host_write),
    .host_addr(vif.host_addr),
    .host_wdata(vif.host_wdata),
    .host_rvalid(vif.host_rvalid),
    .host_rdata(vif.host_rdata),
    .gpu_cmd_valid(vif.gpu_cmd_valid),
    .gpu_cmd_ready(vif.gpu_cmd_ready),
    .gpu_cmd_opcode(vif.gpu_cmd_opcode),
    .gpu_cmd_job_id(vif.gpu_cmd_job_id),
    .gpu_busy(vif.gpu_busy),
    .gpu_done(vif.gpu_done),
    .gpu_error(vif.gpu_error),
    .irq(vif.irq)
  );

  initial begin
    vif.rst_n = 0;
    vif.host_valid = 0;
    vif.host_write = 0;
    vif.host_addr = 0;
    vif.host_wdata = 0;
    vif.gpu_cmd_ready = 0;
    vif.gpu_busy = 0;
    vif.gpu_done = 0;
    vif.gpu_error = 0;
    repeat (4) @(negedge clk);
    vif.rst_n = 1;
  end

  // Simple downstream engine model: accept commands and pulse completion.
  always @(negedge clk) begin
    vif.gpu_done <= 0;
    if (vif.rst_n && vif.gpu_cmd_valid && vif.gpu_cmd_ready)
      vif.gpu_done <= 1;
  end

  initial begin
    uvm_config_db#(virtual gmc_if)::set(null, "*", "vif", vif);
    run_test("gmc_smoke_test");
  end
endmodule

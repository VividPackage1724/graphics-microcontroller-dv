`timescale 1ns/1ps

module tb_graphics_microcontroller;
  logic clk = 1'b0;
  always #5 clk = ~clk;

  logic rst_n;
  logic host_valid, host_write;
  logic [7:0] host_addr;
  logic [31:0] host_wdata;
  logic host_ready, host_rvalid;
  logic [31:0] host_rdata;
  logic gpu_cmd_valid, gpu_cmd_ready, gpu_busy, gpu_done, gpu_error;
  logic [7:0] gpu_cmd_opcode;
  logic [15:0] gpu_cmd_job_id;
  logic irq;

  graphics_microcontroller dut (.*);

  task automatic host_access(
    input logic wr,
    input logic [7:0] addr,
    input logic [31:0] data,
    output logic [31:0] response
  );
    @(negedge clk);
    host_valid = 1'b1;
    host_write = wr;
    host_addr = addr;
    host_wdata = data;
    @(posedge clk);
    if (!host_ready) $fatal(1, "Host request unexpectedly stalled");
    @(negedge clk);
    host_valid = 1'b0;
    @(posedge clk);
    response = host_rdata;
  endtask

  logic [31:0] response;
  initial begin
    rst_n = 1'b0;
    host_valid = 1'b0;
    host_write = 1'b0;
    host_addr = '0;
    host_wdata = '0;
    gpu_cmd_ready = 1'b0;
    gpu_busy = 1'b0;
    gpu_done = 1'b0;
    gpu_error = 1'b0;
    repeat (3) @(posedge clk);
    rst_n = 1'b1;

    host_access(1'b0, 8'h04, 32'b0, response);
    if (response[0] !== 1'b1) $fatal(1, "Ready status reset value incorrect");

    host_access(1'b1, 8'h00, 32'h0000_0005, response);
    host_access(1'b1, 8'h0C, 32'h0000_1234, response);
    host_access(1'b1, 8'h08, 32'h0000_0002, response);

    wait (gpu_cmd_valid);
    if (gpu_cmd_opcode !== 8'h02) $fatal(1, "Unexpected command opcode");
    if (gpu_cmd_job_id !== 16'h1234) $fatal(1, "Unexpected job ID");

    repeat (3) begin
      @(posedge clk);
      if (!gpu_cmd_valid || gpu_cmd_opcode !== 8'h02 ||
          gpu_cmd_job_id !== 16'h1234)
        $fatal(1, "Command payload changed under backpressure");
    end

    @(negedge clk);
    gpu_cmd_ready = 1'b1;
    @(posedge clk);
    @(negedge clk);
    gpu_cmd_ready = 1'b0;

    gpu_done = 1'b1;
    @(posedge clk);
    @(negedge clk);
    gpu_done = 1'b0;
    #1;
    if (!irq) $fatal(1, "Completion interrupt did not assert");

    host_access(1'b1, 8'h14, 32'h1, response);
    #1;
    if (irq) $fatal(1, "IRQ did not clear");

    host_access(1'b1, 8'h08, 32'h0000_00FF, response);
    host_access(1'b0, 8'h18, 32'b0, response);
    if (response[0] !== 1'b1) $fatal(1, "Invalid opcode did not set error");

    $display("PASS: GMC directed smoke test");
    $finish;
  end
endmodule

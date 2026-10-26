module mock_execution_engine #(
  parameter int LATENCY = 3
) (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        ready_enable,
  input  logic        gpu_cmd_valid,
  output logic        gpu_cmd_ready,
  input  logic [7:0]  gpu_cmd_opcode,
  input  logic [15:0] gpu_cmd_job_id,
  output logic        exec_done,
  output logic        exec_error
);
  logic busy;
  int unsigned cycles_remaining;
  logic [7:0] active_opcode;
  logic [15:0] active_job_id;

  always_comb gpu_cmd_ready = ready_enable && !busy;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      busy             <= 1'b0;
      cycles_remaining <= 0;
      active_opcode    <= '0;
      active_job_id    <= '0;
      exec_done        <= 1'b0;
      exec_error       <= 1'b0;
    end else begin
      exec_done  <= 1'b0;
      exec_error <= 1'b0;
      if (!busy && gpu_cmd_valid && gpu_cmd_ready) begin
        busy             <= 1'b1;
        cycles_remaining <= LATENCY;
        active_opcode    <= gpu_cmd_opcode;
        active_job_id    <= gpu_cmd_job_id;
      end else if (busy) begin
        if (cycles_remaining <= 1) begin
          busy             <= 1'b0;
          exec_done        <= 1'b1;
          exec_error       <= (active_opcode == 8'hFF);
          cycles_remaining <= 0;
        end else begin
          cycles_remaining <= cycles_remaining - 1;
        end
      end
    end
  end
endmodule

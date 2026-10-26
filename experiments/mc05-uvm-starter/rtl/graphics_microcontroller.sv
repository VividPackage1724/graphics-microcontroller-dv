module graphics_microcontroller (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        job_valid,
  output logic        job_ready,
  input  logic [7:0]  job_opcode,
  input  logic [15:0] job_id,
  output logic        gpu_cmd_valid,
  input  logic        gpu_cmd_ready,
  output logic [7:0]  gpu_cmd_opcode,
  output logic [15:0] gpu_cmd_job_id,
  input  logic        exec_done,
  input  logic        exec_error,
  output logic        completion_valid,
  output logic [15:0] completion_job_id,
  output logic        completion_status,
  input  logic        interrupt_ack,
  output logic        interrupt
);
  typedef enum logic [1:0] {IDLE, DISPATCH, WAIT_DONE, COMPLETE} state_t;
  state_t state;
  logic [7:0]  cmd_opcode_reg;
  logic [15:0] cmd_job_id_reg;
  logic [15:0] active_job_id_reg;
  logic        completion_status_reg;

  always_comb begin
    job_ready         = (state == IDLE);
    gpu_cmd_valid     = (state == DISPATCH);
    gpu_cmd_opcode    = cmd_opcode_reg;
    gpu_cmd_job_id    = cmd_job_id_reg;
    completion_valid  = (state == COMPLETE);
    completion_job_id = active_job_id_reg;
    completion_status = completion_status_reg;
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      state                 <= IDLE;
      cmd_opcode_reg        <= '0;
      cmd_job_id_reg        <= '0;
      active_job_id_reg     <= '0;
      completion_status_reg <= 1'b0;
      interrupt             <= 1'b0;
    end else begin
      if (interrupt_ack) interrupt <= 1'b0;
      case (state)
        IDLE: if (job_valid && job_ready) begin
          cmd_opcode_reg    <= job_opcode;
          cmd_job_id_reg    <= job_id;
          active_job_id_reg <= job_id;
          state             <= DISPATCH;
        end
        DISPATCH: if (gpu_cmd_valid && gpu_cmd_ready) state <= WAIT_DONE;
        WAIT_DONE: if (exec_done) begin
          completion_status_reg <= exec_error;
          interrupt             <= 1'b1;
          state                 <= COMPLETE;
        end
        COMPLETE: state <= IDLE;
        default: state <= IDLE;
      endcase
    end
  end
endmodule

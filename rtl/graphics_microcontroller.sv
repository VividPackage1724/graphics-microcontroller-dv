module graphics_microcontroller (
  input  logic        clk,
  input  logic        rst_n,

  input  logic        host_valid,
  output logic        host_ready,
  input  logic        host_write,
  input  logic [7:0]  host_addr,
  input  logic [31:0] host_wdata,
  output logic        host_rvalid,
  output logic [31:0] host_rdata,

  // GPU command/engine completion interface
  output logic        gpu_cmd_valid,
  input  logic        gpu_cmd_ready,
  output logic [7:0]  gpu_cmd_opcode,
  output logic [15:0] gpu_cmd_job_id,
  input  logic        gpu_busy,
  input  logic        gpu_done,
  input  logic        gpu_error,

  // DMA request/response contract: one request handshake followed by one response.
  output logic        dma_req_valid,
  input  logic        dma_req_ready,
  output logic [31:0] dma_src_addr,
  output logic [31:0] dma_dst_addr,
  output logic [31:0] dma_length,
  input  logic        dma_rsp_valid,
  input  logic        dma_rsp_error,
  output logic        dma_busy,

  output logic        irq
);
  localparam logic [7:0] ADDR_CONTROL      = 8'h00;
  localparam logic [7:0] ADDR_STATUS       = 8'h04;
  localparam logic [7:0] ADDR_COMMAND      = 8'h08;
  localparam logic [7:0] ADDR_JOB_CONFIG   = 8'h0C;
  localparam logic [7:0] ADDR_IRQ_STATUS   = 8'h10;
  localparam logic [7:0] ADDR_IRQ_CLEAR    = 8'h14;
  localparam logic [7:0] ADDR_ERROR_STATUS = 8'h18;
  localparam logic [7:0] ADDR_DMA_SRC      = 8'h1C;
  localparam logic [7:0] ADDR_DMA_DST      = 8'h20;
  localparam logic [7:0] ADDR_DMA_LENGTH   = 8'h24;

  typedef enum logic [2:0] {
    JOB_IDLE, JOB_DMA_START, JOB_DMA_WAIT, JOB_GPU_DISPATCH, JOB_GPU_WAIT
  } job_state_t;
  job_state_t job_state;

  logic enable_reg, irq_enable_reg;
  logic error_sticky, completion_pending, error_pending;
  logic [15:0] job_id_reg;
  logic [31:0] dma_src_reg, dma_dst_reg, dma_length_reg;
  logic fifo_clear, fifo_push, fifo_pop;
  logic [119:0] fifo_din, fifo_dout;
  logic fifo_empty, fifo_full;
  logic [3:0] fifo_count;
  logic soft_reset_req, request_accept;
  logic [31:0] read_value;
  logic address_valid;
  logic dma_start_valid, dma_start_ready, dma_done, dma_error, dma_cancel;
  logic [31:0] active_src, active_dst, active_length;
  logic active_job;
  logic gpu_accept;

  function automatic logic supported_opcode(input logic [7:0] opcode);
    supported_opcode = (opcode == 8'h01) || (opcode == 8'h02) ||
                       (opcode == 8'h03) || (opcode == 8'h04);
  endfunction

  assign host_ready = 1'b1;
  assign request_accept = host_valid && host_ready;
  // FIFO descriptor snapshots all per-job configuration at submit time.
  assign fifo_din = {job_id_reg, host_wdata[7:0], dma_src_reg,
                     dma_dst_reg, dma_length_reg};
  assign fifo_push = request_accept && host_write &&
                     (host_addr == ADDR_COMMAND) && enable_reg &&
                     !fifo_full && supported_opcode(host_wdata[7:0]);
  assign active_job = (job_state != JOB_IDLE);
  assign active_src = fifo_dout[95:64];
  assign active_dst = fifo_dout[63:32];
  assign active_length = fifo_dout[31:0];
  assign gpu_cmd_valid = (job_state == JOB_GPU_DISPATCH);
  assign gpu_cmd_opcode = fifo_dout[103:96];
  assign gpu_cmd_job_id = fifo_dout[119:104];
  assign gpu_accept = gpu_cmd_valid && gpu_cmd_ready;
  assign fifo_pop = gpu_accept || (dma_error && active_job);
  assign dma_start_valid = (job_state == JOB_DMA_START);
  assign dma_cancel = soft_reset_req;
  assign irq = irq_enable_reg && (completion_pending || error_pending);
  assign fifo_clear = soft_reset_req;

  command_fifo #(.WIDTH(120), .DEPTH(8)) u_command_fifo (
    .clk, .rst_n, .clear(fifo_clear), .push(fifo_push), .din(fifo_din),
    .pop(fifo_pop), .dout(fifo_dout), .empty(fifo_empty), .full(fifo_full),
    .count(fifo_count)
  );

  dma_interface u_dma_interface (
    .clk, .rst_n, .cancel(dma_cancel),
    .start_valid(dma_start_valid), .start_ready(dma_start_ready),
    .start_src_addr(active_src), .start_dst_addr(active_dst),
    .start_length(active_length),
    .dma_req_valid, .dma_req_ready, .dma_src_addr, .dma_dst_addr, .dma_length,
    .dma_rsp_valid, .dma_rsp_error, .busy(dma_busy),
    .done_pulse(dma_done), .error_pulse(dma_error)
  );

  always_comb begin
    address_valid = (host_addr[1:0] == 2'b00) &&
                    ((host_addr == ADDR_CONTROL) || (host_addr == ADDR_STATUS) ||
                     (host_addr == ADDR_COMMAND) || (host_addr == ADDR_JOB_CONFIG) ||
                     (host_addr == ADDR_IRQ_STATUS) || (host_addr == ADDR_IRQ_CLEAR) ||
                     (host_addr == ADDR_ERROR_STATUS) || (host_addr == ADDR_DMA_SRC) ||
                     (host_addr == ADDR_DMA_DST) || (host_addr == ADDR_DMA_LENGTH));
    read_value = 32'b0;
    case (host_addr)
      ADDR_CONTROL:      read_value = {29'b0, irq_enable_reg, 1'b0, enable_reg};
      ADDR_STATUS:       read_value = {26'b0, active_job, dma_busy, fifo_full,
                                       error_sticky, gpu_busy, !fifo_full};
      ADDR_JOB_CONFIG:   read_value = {16'b0, job_id_reg};
      ADDR_IRQ_STATUS:   read_value = {30'b0, error_pending, completion_pending};
      ADDR_ERROR_STATUS: read_value = {31'b0, error_sticky};
      ADDR_DMA_SRC:      read_value = dma_src_reg;
      ADDR_DMA_DST:      read_value = dma_dst_reg;
      ADDR_DMA_LENGTH:   read_value = dma_length_reg;
      default:           read_value = 32'b0;
    endcase
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      enable_reg <= 1'b0;
      irq_enable_reg <= 1'b0;
      job_id_reg <= '0;
      dma_src_reg <= '0;
      dma_dst_reg <= '0;
      dma_length_reg <= '0;
      host_rvalid <= 1'b0;
      host_rdata <= '0;
      error_sticky <= 1'b0;
      completion_pending <= 1'b0;
      error_pending <= 1'b0;
      soft_reset_req <= 1'b0;
      job_state <= JOB_IDLE;
    end else begin
      host_rvalid <= 1'b0;
      soft_reset_req <= 1'b0;

      if (request_accept) begin
        host_rvalid <= 1'b1;
        if (!host_write) begin
          host_rdata <= read_value;
          if (!address_valid) error_sticky <= 1'b1;
        end else begin
          host_rdata <= 32'b0;
          if (!address_valid) begin
            error_sticky <= 1'b1;
          end else begin
            case (host_addr)
              ADDR_CONTROL: begin
                enable_reg <= host_wdata[0];
                irq_enable_reg <= host_wdata[2];
                if (host_wdata[1]) soft_reset_req <= 1'b1;
              end
              ADDR_COMMAND: begin
                if (!enable_reg || fifo_full || !supported_opcode(host_wdata[7:0]) ||
                    dma_length_reg == 0)
                  error_sticky <= 1'b1;
              end
              ADDR_JOB_CONFIG: job_id_reg <= host_wdata[15:0];
              ADDR_DMA_SRC: dma_src_reg <= host_wdata;
              ADDR_DMA_DST: dma_dst_reg <= host_wdata;
              ADDR_DMA_LENGTH: dma_length_reg <= host_wdata;
              ADDR_IRQ_CLEAR: begin
                if (host_wdata[0]) completion_pending <= 1'b0;
                if (host_wdata[1]) error_pending <= 1'b0;
                if (host_wdata[2]) error_sticky <= 1'b0;
              end
              default: error_sticky <= 1'b1;
            endcase
          end
        end
      end

      // A queued descriptor is automatically launched through DMA, then dispatched
      // to the GPU only after the DMA response reports success.
      case (job_state)
        JOB_IDLE: if (enable_reg && !fifo_empty) job_state <= JOB_DMA_START;
        JOB_DMA_START: if (dma_start_valid && dma_start_ready) job_state <= JOB_DMA_WAIT;
        JOB_DMA_WAIT: begin
          if (dma_done) job_state <= JOB_GPU_DISPATCH;
          else if (dma_error) begin
            job_state <= JOB_IDLE;
            error_pending <= 1'b1;
            error_sticky <= 1'b1;
          end
        end
        JOB_GPU_DISPATCH: if (gpu_accept) job_state <= JOB_GPU_WAIT;
        JOB_GPU_WAIT: begin
          if (gpu_done) begin
            completion_pending <= 1'b1;
            job_state <= JOB_IDLE;
          end
          if (gpu_error) begin
            error_pending <= 1'b1;
            error_sticky <= 1'b1;
            job_state <= JOB_IDLE;
          end
        end
        default: job_state <= JOB_IDLE;
      endcase

      if (dma_error) begin
        error_pending <= 1'b1;
        error_sticky <= 1'b1;
      end
      if (gpu_error) begin
        error_pending <= 1'b1;
        error_sticky <= 1'b1;
      end
      if (soft_reset_req) begin
        enable_reg <= 1'b0;
        irq_enable_reg <= 1'b0;
        job_id_reg <= '0;
        dma_src_reg <= '0;
        dma_dst_reg <= '0;
        dma_length_reg <= '0;
        error_sticky <= 1'b0;
        completion_pending <= 1'b0;
        error_pending <= 1'b0;
        job_state <= JOB_IDLE;
      end
    end
  end
endmodule

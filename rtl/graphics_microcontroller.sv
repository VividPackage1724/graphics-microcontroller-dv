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

  output logic        gpu_cmd_valid,
  input  logic        gpu_cmd_ready,
  output logic [7:0]  gpu_cmd_opcode,
  output logic [15:0] gpu_cmd_job_id,
  input  logic        gpu_busy,
  input  logic        gpu_done,
  input  logic        gpu_error,

  output logic        irq
);
  localparam logic [7:0] ADDR_CONTROL     = 8'h00;
  localparam logic [7:0] ADDR_STATUS      = 8'h04;
  localparam logic [7:0] ADDR_COMMAND     = 8'h08;
  localparam logic [7:0] ADDR_JOB_CONFIG  = 8'h0C;
  localparam logic [7:0] ADDR_IRQ_STATUS  = 8'h10;
  localparam logic [7:0] ADDR_IRQ_CLEAR   = 8'h14;
  localparam logic [7:0] ADDR_ERROR_STATUS= 8'h18;

  logic enable_reg, irq_enable_reg;
  logic error_sticky;
  logic completion_pending, error_pending;
  logic [15:0] job_id_reg;
  logic fifo_clear, fifo_push, fifo_pop;
  logic [23:0] fifo_din, fifo_dout;
  logic fifo_empty, fifo_full;
  logic [3:0] fifo_count;
  logic soft_reset_req;
  logic request_accept;
  logic [31:0] read_value;
  logic address_valid;

  assign host_ready = 1'b1;
  assign request_accept = host_valid && host_ready;
  assign fifo_din = {job_id_reg, host_wdata[7:0]};
  assign fifo_push = request_accept && host_write &&
                     (host_addr == ADDR_COMMAND) && enable_reg &&
                     !fifo_full && supported_opcode(host_wdata[7:0]);
  assign fifo_pop = gpu_cmd_valid && gpu_cmd_ready;
  assign gpu_cmd_valid = !fifo_empty && enable_reg;
  assign gpu_cmd_opcode = fifo_dout[7:0];
  assign gpu_cmd_job_id = fifo_dout[23:8];
  assign irq = irq_enable_reg && (completion_pending || error_pending);
  assign fifo_clear = soft_reset_req;

  function automatic logic supported_opcode(input logic [7:0] opcode);
    supported_opcode = (opcode == 8'h01) || (opcode == 8'h02) ||
                       (opcode == 8'h03) || (opcode == 8'h04);
  endfunction

  command_fifo #(.WIDTH(24), .DEPTH(8)) u_command_fifo (
    .clk, .rst_n, .clear(fifo_clear), .push(fifo_push), .din(fifo_din),
    .pop(fifo_pop), .dout(fifo_dout), .empty(fifo_empty), .full(fifo_full),
    .count(fifo_count)
  );

  always_comb begin
    address_valid = (host_addr[1:0] == 2'b00) &&
                    ((host_addr == ADDR_CONTROL) ||
                     (host_addr == ADDR_STATUS) ||
                     (host_addr == ADDR_COMMAND) ||
                     (host_addr == ADDR_JOB_CONFIG) ||
                     (host_addr == ADDR_IRQ_STATUS) ||
                     (host_addr == ADDR_IRQ_CLEAR) ||
                     (host_addr == ADDR_ERROR_STATUS));
    read_value = 32'b0;
    case (host_addr)
      ADDR_CONTROL:      read_value = {29'b0, irq_enable_reg, 1'b0, enable_reg};
      ADDR_STATUS:       read_value = {28'b0, fifo_full, error_sticky, gpu_busy, !fifo_full};
      ADDR_JOB_CONFIG:   read_value = {16'b0, job_id_reg};
      ADDR_IRQ_STATUS:   read_value = {30'b0, error_pending, completion_pending};
      ADDR_ERROR_STATUS: read_value = {31'b0, error_sticky};
      default:           read_value = 32'b0;
    endcase
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      enable_reg        <= 1'b0;
      irq_enable_reg    <= 1'b0;
      job_id_reg        <= '0;
      host_rvalid       <= 1'b0;
      host_rdata        <= '0;
      error_sticky      <= 1'b0;
      completion_pending<= 1'b0;
      error_pending     <= 1'b0;
      soft_reset_req    <= 1'b0;
    end else begin
      host_rvalid    <= 1'b0;
      soft_reset_req <= 1'b0;

      if (request_accept) begin
        host_rvalid <= 1'b1;
        if (!host_write) begin
          host_rdata <= read_value;
          if (!address_valid)
            error_sticky <= 1'b1;
        end else begin
          host_rdata <= 32'b0;
          if (!address_valid) begin
            error_sticky <= 1'b1;
          end else begin
            case (host_addr)
              ADDR_CONTROL: begin
                enable_reg     <= host_wdata[0];
                irq_enable_reg <= host_wdata[2];
                if (host_wdata[1])
                  soft_reset_req <= 1'b1;
              end
              ADDR_COMMAND: begin
                if (!enable_reg || fifo_full || !supported_opcode(host_wdata[7:0]))
                  error_sticky <= 1'b1;
              end
              ADDR_JOB_CONFIG: job_id_reg <= host_wdata[15:0];
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

      if (gpu_done) begin
        completion_pending <= 1'b1;
      end
      if (gpu_error) begin
        error_pending <= 1'b1;
        error_sticky  <= 1'b1;
      end

      if (soft_reset_req) begin
        enable_reg         <= 1'b0;
        irq_enable_reg     <= 1'b0;
        job_id_reg         <= '0;
        error_sticky       <= 1'b0;
        completion_pending <= 1'b0;
        error_pending      <= 1'b0;
      end
    end
  end
endmodule

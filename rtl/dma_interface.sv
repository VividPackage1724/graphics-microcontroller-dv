// Single-outstanding DMA transaction sequencer. The memory subsystem owns the
// actual data movement and returns exactly one response for each accepted request.
module dma_interface (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        cancel,

  input  logic        start_valid,
  output logic        start_ready,
  input  logic [31:0] start_src_addr,
  input  logic [31:0] start_dst_addr,
  input  logic [31:0] start_length,

  output logic        dma_req_valid,
  input  logic        dma_req_ready,
  output logic [31:0] dma_src_addr,
  output logic [31:0] dma_dst_addr,
  output logic [31:0] dma_length,

  input  logic        dma_rsp_valid,
  input  logic        dma_rsp_error,
  output logic        busy,
  output logic        done_pulse,
  output logic        error_pulse
);
  typedef enum logic [1:0] {DMA_IDLE, DMA_REQUEST, DMA_RESPONSE} dma_state_t;
  dma_state_t state;
  logic [31:0] src_q, dst_q, length_q;

  assign start_ready  = (state == DMA_IDLE);
  assign dma_req_valid = (state == DMA_REQUEST);
  assign dma_src_addr = src_q;
  assign dma_dst_addr = dst_q;
  assign dma_length   = length_q;
  assign busy = (state != DMA_IDLE);

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      state       <= DMA_IDLE;
      src_q       <= '0;
      dst_q       <= '0;
      length_q    <= '0;
      done_pulse  <= 1'b0;
      error_pulse <= 1'b0;
    end else begin
      done_pulse  <= 1'b0;
      error_pulse <= 1'b0;
      if (cancel) begin
        state <= DMA_IDLE;
      end else begin
        case (state)
          DMA_IDLE: begin
            if (start_valid && start_ready) begin
              src_q    <= start_src_addr;
              dst_q    <= start_dst_addr;
              length_q <= start_length;
              if (start_length == 0) begin
                error_pulse <= 1'b1;
                state <= DMA_IDLE;
              end else begin
                state <= DMA_REQUEST;
              end
            end
          end
          DMA_REQUEST: begin
            if (dma_req_valid && dma_req_ready)
              state <= DMA_RESPONSE;
          end
          DMA_RESPONSE: begin
            if (dma_rsp_valid) begin
              if (dma_rsp_error) error_pulse <= 1'b1;
              else               done_pulse  <= 1'b1;
              state <= DMA_IDLE;
            end
          end
          default: state <= DMA_IDLE;
        endcase
      end
    end
  end
endmodule

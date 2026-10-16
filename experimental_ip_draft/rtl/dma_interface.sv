module dma_interface #(
    parameter int TIMEOUT_CYCLES = 1024
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start_valid,
    output logic        start_ready,
    input  logic [31:0] start_addr,
    input  logic [15:0] start_length,
    output logic        dma_req_valid,
    input  logic        dma_req_ready,
    output logic [31:0] dma_req_addr,
    output logic [15:0] dma_req_length,
    input  logic        dma_rsp_valid,
    output logic        dma_rsp_ready,
    input  logic        dma_rsp_error,
    output logic        busy,
    output logic        done_pulse,
    output logic        error_pulse
);
    localparam int TIMER_WIDTH =
        (TIMEOUT_CYCLES <= 1) ? 1 : $clog2(TIMEOUT_CYCLES + 1);

    typedef enum logic [1:0] { DMA_IDLE, DMA_SEND, DMA_WAIT } dma_state_t;
    dma_state_t state;
    logic [TIMER_WIDTH-1:0] timeout_count;
    logic [31:0] addr_reg;
    logic [15:0] length_reg;

    assign start_ready = (state == DMA_IDLE);
    assign dma_req_valid = (state == DMA_SEND);
    assign dma_req_addr = addr_reg;
    assign dma_req_length = length_reg;
    assign dma_rsp_ready = (state == DMA_WAIT);
    assign busy = (state != DMA_IDLE);

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= DMA_IDLE;
            timeout_count <= '0;
            addr_reg <= '0;
            length_reg <= '0;
            done_pulse <= 1'b0;
            error_pulse <= 1'b0;
        end else begin
            done_pulse <= 1'b0;
            error_pulse <= 1'b0;
            case (state)
                DMA_IDLE: begin
                    timeout_count <= '0;
                    if (start_valid && start_ready) begin
                        addr_reg <= start_addr;
                        length_reg <= start_length;
                        state <= DMA_SEND;
                    end
                end
                DMA_SEND: begin
                    if (dma_req_valid && dma_req_ready) begin
                        timeout_count <= '0;
                        state <= DMA_WAIT;
                    end else if (timeout_count >= TIMEOUT_CYCLES - 1) begin
                        error_pulse <= 1'b1;
                        state <= DMA_IDLE;
                        timeout_count <= '0;
                    end else begin
                        timeout_count <= timeout_count + 1'b1;
                    end
                end
                DMA_WAIT: begin
                    if (dma_rsp_valid && dma_rsp_ready) begin
                        if (dma_rsp_error)
                            error_pulse <= 1'b1;
                        else
                            done_pulse <= 1'b1;
                        state <= DMA_IDLE;
                        timeout_count <= '0;
                    end else if (timeout_count >= TIMEOUT_CYCLES - 1) begin
                        error_pulse <= 1'b1;
                        state <= DMA_IDLE;
                        timeout_count <= '0;
                    end else begin
                        timeout_count <= timeout_count + 1'b1;
                    end
                end
                default: begin
                    state <= DMA_IDLE;
                    timeout_count <= '0;
                    error_pulse <= 1'b1;
                end
            endcase
        end
    end
endmodule

module gpu_command_controller #(
    parameter int FIFO_DEPTH = 8,
    parameter int JOB_TIMEOUT_CYCLES = 1024,
    parameter int DMA_TIMEOUT_CYCLES = 1024
) (
    input  logic         clk,
    input  logic         rst_n,

    // Simple host request/ready interface; not AXI-Lite.
    input  logic         host_valid,
    output logic         host_ready,
    input  logic         host_write,
    input  logic [7:0]   host_addr,
    input  logic [31:0]  host_wdata,
    output logic         host_rvalid,
    output logic [31:0]  host_rdata,

    // Accelerator command and completion interface.
    output logic         engine_cmd_valid,
    input  logic         engine_cmd_ready,
    output logic [7:0]   engine_opcode,
    output logic [15:0]  engine_job_id,
    output logic [31:0]  engine_src_addr,
    output logic [31:0]  engine_dst_addr,
    output logic [15:0]  engine_length,
    input  logic         engine_done,
    input  logic         engine_error,

    // External DMA command/response interface.
    // One accepted request represents a complete src->dst transfer of length bytes.
    output logic         dma_req_valid,
    input  logic         dma_req_ready,
    output logic [31:0]  dma_req_src_addr,
    output logic [31:0]  dma_req_dst_addr,
    output logic [15:0]  dma_req_length,
    input  logic         dma_rsp_valid,
    output logic         dma_rsp_ready,
    input  logic         dma_rsp_error,
    output logic         dma_busy,
    output logic         dma_done,
    output logic         dma_error,

    output logic         busy,
    output logic         irq,
    output logic [1:0]   irq_status
);
    logic submit_valid, submit_ready;
    logic [127:0] submit_descriptor;
    logic fifo_out_valid, fifo_out_ready;
    logic [127:0] fifo_out_descriptor;
    logic job_busy, job_completion, job_error;
    logic [15:0] active_job_id;
    logic [1:0] irq_enable, irq_clear;
    logic status_error;

    logic dma_start_valid, dma_start_ready;
    logic [31:0] dma_start_src_addr, dma_start_dst_addr;
    logic [15:0] dma_start_length;

    assign busy = job_busy | dma_busy;
    assign status_error = job_error | dma_error;

    register_bank u_register_bank (
        .clk(clk), .rst_n(rst_n),
        .host_valid(host_valid), .host_ready(host_ready),
        .host_write(host_write), .host_addr(host_addr), .host_wdata(host_wdata),
        .host_rvalid(host_rvalid), .host_rdata(host_rdata),
        .submit_valid(submit_valid), .submit_ready(submit_ready),
        .submit_descriptor(submit_descriptor),
        .status_busy(busy), .status_error(status_error),
        .status_complete(job_completion), .irq_status(irq_status),
        .irq_enable(irq_enable), .irq_clear(irq_clear)
    );

    command_fifo #(.DATA_WIDTH(128), .DEPTH(FIFO_DEPTH)) u_command_fifo (
        .clk(clk), .rst_n(rst_n),
        .in_valid(submit_valid), .in_ready(submit_ready), .in_data(submit_descriptor),
        .out_valid(fifo_out_valid), .out_ready(fifo_out_ready),
        .out_data(fifo_out_descriptor)
    );

    job_controller #(.TIMEOUT_CYCLES(JOB_TIMEOUT_CYCLES)) u_job_controller (
        .clk(clk), .rst_n(rst_n),
        .fifo_valid(fifo_out_valid), .fifo_ready(fifo_out_ready),
        .fifo_descriptor(fifo_out_descriptor),
        .dma_start_valid(dma_start_valid), .dma_start_ready(dma_start_ready),
        .dma_start_src_addr(dma_start_src_addr),
        .dma_start_dst_addr(dma_start_dst_addr),
        .dma_start_length(dma_start_length),
        .dma_done(dma_done), .dma_error(dma_error),
        .engine_cmd_valid(engine_cmd_valid), .engine_cmd_ready(engine_cmd_ready),
        .engine_opcode(engine_opcode), .engine_job_id(engine_job_id),
        .engine_src_addr(engine_src_addr), .engine_dst_addr(engine_dst_addr),
        .engine_length(engine_length), .engine_done(engine_done),
        .engine_error(engine_error), .busy(job_busy),
        .completion_pulse(job_completion), .error_pulse(job_error),
        .active_job_id(active_job_id)
    );

    dma_interface #(.TIMEOUT_CYCLES(DMA_TIMEOUT_CYCLES)) u_dma_interface (
        .clk(clk), .rst_n(rst_n),
        .start_valid(dma_start_valid), .start_ready(dma_start_ready),
        .start_src_addr(dma_start_src_addr), .start_dst_addr(dma_start_dst_addr),
        .start_length(dma_start_length),
        .dma_req_valid(dma_req_valid), .dma_req_ready(dma_req_ready),
        .dma_req_src_addr(dma_req_src_addr), .dma_req_dst_addr(dma_req_dst_addr),
        .dma_req_length(dma_req_length),
        .dma_rsp_valid(dma_rsp_valid), .dma_rsp_ready(dma_rsp_ready),
        .dma_rsp_error(dma_rsp_error), .busy(dma_busy),
        .done_pulse(dma_done), .error_pulse(dma_error)
    );

    interrupt_controller u_interrupt_controller (
        .clk(clk), .rst_n(rst_n),
        .event_complete(job_completion), .event_error(status_error),
        .irq_enable(irq_enable), .irq_clear(irq_clear),
        .irq_status(irq_status), .irq(irq)
    );
endmodule

module job_controller #(
    parameter int TIMEOUT_CYCLES = 1024
) (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         fifo_valid,
    output logic         fifo_ready,
    input  logic [127:0] fifo_descriptor,
    output logic         engine_cmd_valid,
    input  logic         engine_cmd_ready,
    output logic [7:0]   engine_opcode,
    output logic [15:0]  engine_job_id,
    output logic [31:0]  engine_src_addr,
    output logic [31:0]  engine_dst_addr,
    output logic [15:0]  engine_length,
    input  logic         engine_done,
    input  logic         engine_error,
    output logic         busy,
    output logic         completion_pulse,
    output logic         error_pulse,
    output logic [15:0]  active_job_id
);
    localparam int TIMER_WIDTH =
        (TIMEOUT_CYCLES <= 1) ? 1 : $clog2(TIMEOUT_CYCLES + 1);

    typedef enum logic [1:0] { ST_IDLE, ST_DISPATCH, ST_WAIT } state_t;
    state_t state;

    logic [127:0] active_descriptor;
    logic [TIMER_WIDTH-1:0] timeout_count;
    logic descriptor_valid, descriptor_error;
    logic [7:0] decoded_opcode;
    logic [15:0] decoded_job_id;
    logic [31:0] decoded_src_addr, decoded_dst_addr;
    logic [15:0] decoded_length;

    command_decoder u_command_decoder (
        .descriptor(active_descriptor),
        .descriptor_valid(descriptor_valid),
        .descriptor_error(descriptor_error),
        .opcode(decoded_opcode),
        .job_id(decoded_job_id),
        .src_addr(decoded_src_addr),
        .dst_addr(decoded_dst_addr),
        .length(decoded_length)
    );

    assign fifo_ready = (state == ST_IDLE);
    assign busy = (state != ST_IDLE);
    assign engine_cmd_valid = (state == ST_DISPATCH) && descriptor_valid;
    assign engine_opcode = decoded_opcode;
    assign engine_job_id = decoded_job_id;
    assign engine_src_addr = decoded_src_addr;
    assign engine_dst_addr = decoded_dst_addr;
    assign engine_length = decoded_length;
    assign active_job_id = decoded_job_id;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            active_descriptor <= '0;
            timeout_count <= '0;
            completion_pulse <= 1'b0;
            error_pulse <= 1'b0;
        end else begin
            completion_pulse <= 1'b0;
            error_pulse <= 1'b0;

            case (state)
                ST_IDLE: begin
                    timeout_count <= '0;
                    if (fifo_valid && fifo_ready) begin
                        active_descriptor <= fifo_descriptor;
                        state <= ST_DISPATCH;
                    end
                end
                ST_DISPATCH: begin
                    if (descriptor_error) begin
                        error_pulse <= 1'b1;
                        state <= ST_IDLE;
                    end else if (engine_cmd_valid && engine_cmd_ready) begin
                        timeout_count <= '0;
                        state <= ST_WAIT;
                    end
                end
                ST_WAIT: begin
                    if (engine_error) begin
                        error_pulse <= 1'b1;
                        state <= ST_IDLE;
                        timeout_count <= '0;
                    end else if (engine_done) begin
                        completion_pulse <= 1'b1;
                        state <= ST_IDLE;
                        timeout_count <= '0;
                    end else if (timeout_count >= TIMEOUT_CYCLES - 1) begin
                        error_pulse <= 1'b1;
                        state <= ST_IDLE;
                        timeout_count <= '0;
                    end else begin
                        timeout_count <= timeout_count + 1'b1;
                    end
                end
                default: begin
                    state <= ST_IDLE;
                    timeout_count <= '0;
                    error_pulse <= 1'b1;
                end
            endcase
        end
    end
endmodule

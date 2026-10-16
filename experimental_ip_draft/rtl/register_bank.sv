module register_bank (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         host_valid,
    output logic         host_ready,
    input  logic         host_write,
    input  logic [7:0]   host_addr,
    input  logic [31:0]  host_wdata,
    output logic         host_rvalid,
    output logic [31:0]  host_rdata,
    output logic         submit_valid,
    input  logic         submit_ready,
    output logic [127:0] submit_descriptor,
    input  logic         status_busy,
    input  logic         status_error,
    input  logic         status_complete,
    input  logic [1:0]   irq_status,
    output logic [1:0]   irq_enable,
    output logic [1:0]   irq_clear
);
    localparam logic [7:0] ADDR_CONTROL    = 8'h00;
    localparam logic [7:0] ADDR_STATUS     = 8'h04;
    localparam logic [7:0] ADDR_OPCODE     = 8'h08;
    localparam logic [7:0] ADDR_JOB_ID     = 8'h0C;
    localparam logic [7:0] ADDR_SRC_ADDR   = 8'h10;
    localparam logic [7:0] ADDR_DST_ADDR   = 8'h14;
    localparam logic [7:0] ADDR_LENGTH     = 8'h18;
    localparam logic [7:0] ADDR_SUBMIT     = 8'h1C;
    localparam logic [7:0] ADDR_IRQ_STATUS = 8'h20;
    localparam logic [7:0] ADDR_IRQ_ENABLE = 8'h24;

    logic [7:0] opcode_reg;
    logic [15:0] job_id_reg, length_reg;
    logic [31:0] src_addr_reg, dst_addr_reg;
    logic accept, submit_write;

    assign submit_write = host_valid && host_write && (host_addr == ADDR_SUBMIT);
    always_comb begin
        host_ready = submit_write ? submit_ready : 1'b1;
    end

    assign accept = host_valid && host_ready;
    assign submit_valid = submit_write && host_ready;

    assign submit_descriptor = {
        24'd0, length_reg, dst_addr_reg, src_addr_reg, job_id_reg, opcode_reg
    };

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            opcode_reg <= 8'h02;
            job_id_reg <= '0;
            src_addr_reg <= '0;
            dst_addr_reg <= '0;
            length_reg <= '0;
            irq_enable <= '0;
            irq_clear <= '0;
            host_rvalid <= 1'b0;
            host_rdata <= '0;
        end else begin
            host_rvalid <= 1'b0;
            irq_clear <= '0;

            if (accept && !host_write) begin
                host_rvalid <= 1'b1;
                case (host_addr)
                    ADDR_CONTROL: host_rdata <= 32'd0;
                    ADDR_STATUS: host_rdata <= {29'd0, status_complete,
                                                status_error, status_busy};
                    ADDR_OPCODE: host_rdata <= {24'd0, opcode_reg};
                    ADDR_JOB_ID: host_rdata <= {16'd0, job_id_reg};
                    ADDR_SRC_ADDR: host_rdata <= src_addr_reg;
                    ADDR_DST_ADDR: host_rdata <= dst_addr_reg;
                    ADDR_LENGTH: host_rdata <= {16'd0, length_reg};
                    ADDR_IRQ_STATUS: host_rdata <= {30'd0, irq_status};
                    ADDR_IRQ_ENABLE: host_rdata <= {30'd0, irq_enable};
                    default: host_rdata <= 32'hDEAD_BEEF;
                endcase
            end

            if (accept && host_write) begin
                case (host_addr)
                    ADDR_OPCODE: opcode_reg <= host_wdata[7:0];
                    ADDR_JOB_ID: job_id_reg <= host_wdata[15:0];
                    ADDR_SRC_ADDR: src_addr_reg <= host_wdata;
                    ADDR_DST_ADDR: dst_addr_reg <= host_wdata;
                    ADDR_LENGTH: length_reg <= host_wdata[15:0];
                    ADDR_IRQ_STATUS: irq_clear <= host_wdata[1:0];
                    ADDR_IRQ_ENABLE: irq_enable <= host_wdata[1:0];
                    default: begin end
                endcase
            end
        end
    end
endmodule

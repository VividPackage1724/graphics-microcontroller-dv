module command_decoder (
    input  logic [127:0] descriptor,
    output logic         descriptor_valid,
    output logic         descriptor_error,
    output logic [7:0]   opcode,
    output logic [15:0]  job_id,
    output logic [31:0]  src_addr,
    output logic [31:0]  dst_addr,
    output logic [15:0]  length
);
    // Prototype descriptor:
    // [7:0] opcode, [23:8] job_id, [55:24] src,
    // [87:56] dst, [103:88] length, [127:104] reserved.
    localparam logic [7:0] OPCODE_SUBMIT_JOB = 8'h02;

    always_comb begin
        opcode   = descriptor[7:0];
        job_id   = descriptor[23:8];
        src_addr = descriptor[55:24];
        dst_addr = descriptor[87:56];
        length   = descriptor[103:88];

        descriptor_error = (opcode != OPCODE_SUBMIT_JOB)
                         || (length == 16'd0)
                         || (descriptor[127:104] != 24'd0);
        descriptor_valid = !descriptor_error;
    end
endmodule

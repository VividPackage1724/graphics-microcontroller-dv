module gmc_protocol_assertions (
  input logic clk,
  input logic rst_n,
  input logic gpu_cmd_valid,
  input logic gpu_cmd_ready,
  input logic [7:0] gpu_cmd_opcode,
  input logic [15:0] gpu_cmd_job_id,
  input logic irq,
  input logic irq_enable,
  input logic completion_pending,
  input logic error_pending
);
  property p_payload_stable_when_stalled;
    @(posedge clk) disable iff (!rst_n)
      gpu_cmd_valid && !gpu_cmd_ready |=> gpu_cmd_valid &&
        $stable({gpu_cmd_opcode, gpu_cmd_job_id});
  endproperty
  assert property (p_payload_stable_when_stalled);

  property p_irq_gated;
    @(posedge clk) disable iff (!rst_n)
      irq == (irq_enable && (completion_pending || error_pending));
  endproperty
  assert property (p_irq_gated);
endmodule

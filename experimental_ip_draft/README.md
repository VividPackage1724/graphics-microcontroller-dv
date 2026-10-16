# GPU Command & Job Controller — experimental RTL draft

This directory contains an early, unverified RTL draft for a reusable GPU/AI accelerator command controller.

## Files

- `rtl/command_decoder.sv`: fixed-format descriptor validation.
- `rtl/register_bank.sv`: simple host MMIO interface and descriptor submission.
- `rtl/interrupt_controller.sv`: sticky completion/error status.
- `rtl/job_controller.sv`: single-active-job dispatch and timeout.
- `rtl/dma_interface.sv`: single-outstanding DMA request/response wrapper.

## Descriptor format

| Bits | Field |
|---|---|
| [7:0] | Opcode; 8'h02 means SUBMIT_JOB |
| [23:8] | Job ID |
| [55:24] | Source address |
| [87:56] | Destination address |
| [103:88] | Length in bytes |
| [127:104] | Reserved; must be zero |

## Important limitations

This is a draft, not production-qualified IP. It has not been compiled or simulated as part of this commit. It requires lint, self-checking tests, and interface-contract review before integration.

The register bank uses a simple custom host request/ready interface; it is not AXI-Lite compliant. The DMA module is a single-transaction wrapper, not a full DMA engine. Reset/abort semantics and timeout behavior must be specified and verified before production use.

No claim of compatibility with a specific GPU or commercial SoC is made.

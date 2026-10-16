# GPU Command & Job Controller — experimental RTL draft

This directory contains an early RTL prototype for a reusable GPU/AI accelerator command controller.

## RTL files

- rtl/command_fifo.sv — parameterized FIFO with ready/valid flow control.
- rtl/command_decoder.sv — fixed-format descriptor validation.
- rtl/register_bank.sv — simple host MMIO interface and descriptor submission.
- rtl/interrupt_controller.sv — sticky completion/error interrupt status.
- rtl/job_controller.sv — single-active-job dispatch and timeout.
- rtl/dma_interface.sv — single-outstanding DMA request/response wrapper.
- rtl/gpu_command_controller.sv — top-level integration.

## Descriptor format

| Bits | Field |
|---|---|
| [7:0] | Opcode; 8'h02 means SUBMIT_JOB |
| [23:8] | Job ID |
| [55:24] | Source address |
| [87:56] | Destination address |
| [103:88] | Length in bytes |
| [127:104] | Reserved; must be zero |

## Integration notes

The host interface is a custom request/ready interface and is not AXI-Lite compliant.

The DMA interface is instantiated at the top level but remains an auxiliary, independently started transaction port in this draft. A submitted job does not automatically trigger DMA. Connecting job descriptors to DMA execution requires a separately specified dataflow and completion contract.

The FIFO uses a conservative full policy: it does not accept a push in the same cycle as a pop when it starts full.

## Verification status

This is an unverified draft, not production-qualified IP. Run lint/elaboration and self-checking simulation before relying on it. Review timeout boundary conditions, reset and abort semantics, descriptor constraints, bus handshakes, and interrupt-clear/event priority. No claim of compatibility with any specific commercial GPU or SoC is made.

# Graphics Microcontroller (GMC) — RTL Design & Verification

An original, educational SystemVerilog project for a small graphics-command microcontroller. It demonstrates memory-mapped control/status registers, command buffering, ready/valid handshaking, interrupt status, assertions, and a self-checking smoke test.

**This is a learning project, not an implementation of any proprietary Arm, Intel, or AMD design.**

## Scope

- 32-bit host register interface with 8-bit byte addresses
- 8-entry command FIFO
- 8-entry job FIFO with per-job source/destination/length snapshots
- DMA request/response sequencer with a single-outstanding handshake
- Command dispatch interface to a simulated GPU engine
- Completion/error interrupt status
- Register read/write, invalid-command, FIFO-full, and reset behavior
- Self-checking SystemVerilog testbench and Verilator-based simulation

## Repository layout

- `rtl/` — synthesizable design RTL
- `tb/` — self-checking testbench
- `assertions/` — protocol properties
- `docs/` — feature, register, architecture, and verification specifications
- `sim/` — simulation build/run commands

## Run a smoke test

Install Verilator and GNU Make, then run:

```sh
make -C sim
```

The testbench uses plain SystemVerilog and does not require UVM. UVM support is not claimed for this initial open-source simulator setup.

## Initial interface

Host request: `host_valid/host_ready`, `host_write`, `host_addr[7:0]`, `host_wdata[31:0]`.

Host response: one-cycle `host_rvalid` pulse and `host_rdata[31:0]` for reads. Writes also generate `host_rvalid` with zero response data. The host must sample the response pulse; there is no response-ready input in this educational interface.

GPU command: `gpu_cmd_valid/gpu_cmd_ready`, `gpu_cmd_opcode[7:0]`, `gpu_cmd_job_id[15:0]`. The command and job ID remain stable while valid is asserted and ready is low.

DMA flow: program `DMA_SRC` (`0x1C`), `DMA_DST` (`0x20`), and nonzero `DMA_LENGTH` (`0x24`), then write `JOB_CONFIG` (`0x0C`) and submit `COMMAND` (`0x08`). Submission snapshots job ID/opcode/source/destination/length into the FIFO. The controller automatically issues `dma_req_valid`; the external DMA/memory subsystem accepts it with `dma_req_ready`, then returns exactly one `dma_rsp_valid` pulse with `dma_rsp_error` indicating success/failure. Request fields stay stable until request handshake. The GPU command is dispatched only after successful DMA response. A DMA error drops that queued job, sets sticky/error IRQ status, and does not dispatch it to the GPU. The current interface has no DMA timeout; the external subsystem must always return a response or the job remains pending.

## Status

This is the first implementation milestone. Run the provided simulation locally and review the TODOs/issues before treating the design as production-quality IP. 

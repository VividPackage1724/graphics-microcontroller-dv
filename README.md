# Graphics Microcontroller (GMC) — RTL Design & Verification

An original, educational SystemVerilog project for a small graphics-command microcontroller. It demonstrates memory-mapped control/status registers, command buffering, ready/valid handshaking, interrupt status, assertions, and a self-checking smoke test.

**This is a learning project, not an implementation of any proprietary Arm, Intel, or AMD design.**

## Scope

- 32-bit host register interface with 8-bit byte addresses
- 8-entry command FIFO
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

## Status

This is the first implementation milestone. Run the provided simulation locally and review the TODOs/issues before treating the design as production-quality IP. Test results are not claimed unless you run the test yourself.

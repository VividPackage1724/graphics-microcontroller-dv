# Graphics Microcontroller Feature Specification

## 1. Purpose

The Graphics Microcontroller (GMC) is a small command/control block between a host processor and a downstream graphics execution engine. It accepts host register accesses, queues command descriptors, dispatches one descriptor at a time, and records completion/error events.

This project is an original educational design. It is not intended to reproduce a commercial GPU or any vendor's internal microarchitecture.

## 2. Functional requirements

1. Provide a synchronous active-low reset (`rst_n`).
2. Implement a 32-bit memory-mapped host interface with 8-bit byte addresses.
3. Accept one host request whenever `host_valid && host_ready` is true.
4. Return a one-cycle `host_rvalid` pulse after each accepted request. Read responses contain the selected register value; write responses return zero.
5. Buffer up to eight command descriptors.
6. Support command opcodes `0x01 INIT`, `0x02 SUBMIT_JOB`, `0x03 QUERY_STATUS`, and `0x04 STOP`. Other opcodes are invalid.
7. Dispatch the FIFO head using a ready/valid interface. Payload must remain stable while `gpu_cmd_valid && !gpu_cmd_ready`.
8. Track engine busy, completion, and error indications.
9. Set interrupt-pending status for completion and error events when enabled by the control register. Pending status is sticky until cleared or reset.
10. Report invalid register accesses, invalid opcodes, and command FIFO overflow through the error status.
11. A soft reset clears GMC control/status/FIFO state. The external synchronous reset always takes precedence.

## 3. Interface assumptions

- All interface signals are synchronous to `clk`.
- Host addresses are byte addresses; implemented registers are word-aligned.
- Host request inputs must remain valid and stable until accepted.
- The host interface has no response-ready signal. The response is a one-cycle pulse.
- The GPU engine is external to this block. The testbench models its readiness and completion behavior.
- `gpu_done` and `gpu_error` are event inputs expected to be pulsed for one cycle by the engine.

## 4. Command semantics

| Opcode | Name | Initial behavior |
|---|---|---|
| `0x01` | INIT | Enqueued and dispatched like other commands |
| `0x02` | SUBMIT_JOB | Enqueued with the current JOB_CONFIG ID |
| `0x03` | QUERY_STATUS | Enqueued and dispatched like other commands |
| `0x04` | STOP | Enqueued and dispatched like other commands |
| Other | Invalid | Not enqueued; error status is set |

The current descriptor carries an 8-bit opcode and 16-bit job ID. The JOB_CONFIG register supplies the job ID for subsequent command writes.

## 5. Error behavior

The error status is sticky until the error-clear mechanism or reset clears it. The initial RTL exposes a write-one-to-clear bit in `IRQ_CLEAR` for the interrupt-pending flags; detailed error-code expansion is a future extension. Invalid commands and FIFO overflow must not corrupt existing FIFO entries.

## 6. Out of scope

- Rendering, shader execution, memory management, cache/coherency, DMA, and PCIe
- Commercial GPU instruction sets or proprietary register maps
- Clock-domain crossing and asynchronous interfaces
- Full UVM environment in the initial Verilator smoke-test setup
- Performance claims or silicon-level timing closure

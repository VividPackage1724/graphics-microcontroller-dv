# GPU Command Controller RTL — Experimental Draft

This folder contains an educational, synthesizable SystemVerilog prototype for a host-submitted command/job controller. It is not production-ready IP. The RTL has not yet been formally verified or qualified for a target ASIC/FPGA flow.

## Integrated job data flow

1. The host programs opcode, job ID, source address, destination address, and transfer length through the simple request/ready register interface.
2. A write to `ADDR_SUBMIT` pushes a 128-bit descriptor into the command FIFO.
3. The job controller dequeues and validates one descriptor.
4. The controller launches DMA with source address, destination address, and length. The external DMA endpoint must accept the request with `dma_req_valid && dma_req_ready`, perform the entire transfer, and return exactly one response using `dma_rsp_valid && dma_rsp_ready`. `dma_rsp_error` marks a failed transfer.
5. The job controller dispatches the engine command only after a successful DMA response. It waits for `engine_done` or `engine_error`.
6. Completion/error status and interrupt events are generated. DMA request backpressure, DMA response timeout, engine timeout, and DMA/engine errors terminate the active job without dispatching after a failed DMA.

The DMA request fields remain stable while `dma_req_valid` is asserted and `dma_req_ready` is low. A response must correspond to the single outstanding DMA request. This prototype supports one active job and one outstanding DMA operation; it does not define burst splitting, cache coherency, address translation, or memory protection.

## Descriptor format

| Bits | Field |
|---|---|
| [7:0] | opcode; `8'h02` means DMA-assisted job |
| [23:8] | job ID |
| [55:24] | source address |
| [87:56] | destination address |
| [103:88] | transfer length in bytes |
| [127:104] | reserved; must be zero |

Zero-length descriptors are rejected. Address alignment and address-range checks are not implemented.

## DMA endpoint contract

- Accept a command only on `dma_req_valid && dma_req_ready`.
- Treat one accepted command as a complete source-to-destination transfer of `dma_req_length` bytes.
- Keep the request ready/valid protocol independent from response timing; the response can arrive only after the request is accepted.
- Return one response for each accepted command. Assert `dma_rsp_error` for a transfer failure.
- If no response arrives before the configured timeout, the controller aborts the job logically. The external DMA endpoint must not later associate a stale response with a new request; production integration should add transaction IDs or a defined cancellation/reset contract.

## Files

- `rtl/command_fifo.sv` — descriptor FIFO
- `rtl/command_decoder.sv` — descriptor field extraction and basic validation
- `rtl/register_bank.sv` — host register interface
- `rtl/dma_interface.sv` — DMA command/response handshake and timeout
- `rtl/job_controller.sv` — descriptor validation, DMA sequencing, engine dispatch, and job timeout
- `rtl/interrupt_controller.sv` — completion/error interrupt status
- `rtl/gpu_command_controller.sv` — integrated top level

## Verification still required

Compile and elaborate all RTL together; add a self-checking testbench for FIFO backpressure, descriptor rejection, DMA request stalls, successful DMA-before-engine ordering, DMA error, DMA timeout, engine error/timeout, interrupt clearing, and reset during each state. Add assertions for request stability, no engine dispatch before DMA completion, and one completion/error outcome per accepted descriptor.

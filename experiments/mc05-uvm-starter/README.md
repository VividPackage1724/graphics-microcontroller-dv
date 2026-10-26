# Graphics Microcontroller DV

A small RTL and UVM verification project demonstrating a ready/valid GPU command dispatch path, downstream backpressure, completion tracking, and interrupt generation.

## RTL behavior

- Accepts one job at a time when `job_valid && job_ready`.
- Holds `gpu_cmd_valid` and the command payload stable until `gpu_cmd_valid && gpu_cmd_ready`.
- Waits for the mock execution engine to pulse `exec_done`.
- Emits a one-cycle `completion_valid` pulse with the accepted job ID and completion status.
- Raises a sticky interrupt, cleared by `interrupt_ack`.
- The mock engine reports an error for opcode `8'hFF` and success for other opcodes.

## UVM components

- `mc_job_transaction`: job stimulus and monitor event object.
- `mc_sequencer`: provides sequence items to the driver.
- `mc_driver`: submits jobs and controls `ready_enable` to create downstream stalls.
- `mc_monitor`: observes accepted jobs, dispatch handshakes, completion, and checks payload stability under backpressure.
- `mc_scoreboard`: matches host acceptance to dispatch and dispatch to completion.
- `mc_agent`, `mc_env`: component hierarchy and analysis connection.
- `mc_backpressure_test`: submits opcode `12`, ID `0042`, with five stall cycles.
- `mc_error_test`: submits opcode `FF`, ID `00E1`, and expects an error completion.

## Simulation requirements

This is a UVM testbench and requires a simulator with UVM support, such as a supported Questa, VCS, or Xcelium installation. The existing simple directed test can still be run separately with Icarus Verilog, but Icarus does not provide a standard full UVM runtime.

The `sim/filelist.f` is a starting point for simulators that use `UVM_HOME`. Adjust paths and simulator-specific UVM setup as required. Run tests with the equivalent of:

- `+UVM_TESTNAME=mc_backpressure_test`
- `+UVM_TESTNAME=mc_error_test`

## Important scope notes

This is a learning-scale single-outstanding-job controller, not a full GPU microcontroller. The scoreboard derives expected completion status from the documented mock-engine model (opcode `FF` means error). Interrupt acknowledgment is driven by the top-level testbench and can be extended into a separate interrupt agent or sequence.

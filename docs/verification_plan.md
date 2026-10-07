# GMC Verification Plan

## Strategy

Start with a self-checking SystemVerilog testbench and Verilator lint/simulation. Keep tests deterministic and small enough to debug from waveforms. Add randomized traffic and coverage after directed tests are stable. Full UVM is not a prerequisite for the initial open-source flow.

## Directed test matrix

| ID | Scenario | Expected result |
|---|---|---|
| GMC-T01 | Reset | Registers/status/FIFO return to documented reset values |
| GMC-T02 | Read/write JOB_CONFIG | Job ID is stored and read back |
| GMC-T03 | Supported command | Descriptor appears at GPU interface in FIFO order |
| GMC-T04 | GPU backpressure | Valid and descriptor payload remain stable until handshake |
| GMC-T05 | Unsupported opcode | No descriptor enqueued; sticky error set |
| GMC-T06 | FIFO empty/full | Empty FIFO does not dispatch; full FIFO reports overflow without corrupting queued entries |
| GMC-T07 | FIFO ordering | Multiple commands emerge in the same order they were accepted |
| GMC-T08 | Completion event | Completion pending bit sets |
| GMC-T09 | Error event | Error pending and sticky error set |
| GMC-T10 | IRQ mask/clear | IRQ is gated by enable and pending bits clear with W1C |
| GMC-T11 | Invalid address/alignment | Error indication sets |
| GMC-T12 | Soft reset | GMC state and queued commands clear |

## Assertions to add/maintain

- Command payload is stable while valid and not ready.
- FIFO count never exceeds depth and never becomes negative.
- FIFO output order matches accepted command order.
- Reset clears valid/interrupt state.
- No unsupported opcode is dispatched.
- IRQ only asserts when interrupt-enable is set and at least one pending bit is set.

## Coverage goals

Track opcode bins, FIFO occupancy boundaries (0, 1, depth-1, depth), downstream stall lengths, completion/error events, IRQ enabled/disabled, invalid accesses, and reset during idle/traffic. Functional coverage should be added only where the selected simulator supports it; a portable counter-based coverage summary is acceptable.

## Exit criteria

- Lint completes without unexplained warnings.
- All directed tests pass.
- No assertion failures.
- Waveforms are reviewed for reset, command stall, and completion/error cases.
- README reports only tests actually run and passing.

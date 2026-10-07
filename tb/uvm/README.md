# UVM Testbench

This folder contains the first UVM environment scaffold for the GMC RTL.

## Components

- `gmc_if.sv`: interface and host clocking block
- `gmc_uvm_pkg.sv`: host sequence item, sequencer, driver, monitor, agent, scoreboard, environment, and smoke test
- `tb_top.sv`: DUT hookup, reset, and simple downstream GPU-engine model

## Simulator requirements

Use a simulator with a compatible SystemVerilog implementation and Accellera UVM library (for example, a licensed commercial simulator or another environment that explicitly supports the UVM version used). The existing Verilator Makefile runs the non-UVM smoke test only; it does not compile this UVM environment. Do not assume full UVM support in an arbitrary open-source simulator.

## Initial smoke scenario

1. Enable GMC and IRQ.
2. Write a job ID.
3. Read JOB_CONFIG.
4. Submit a job.
5. The simple GPU model accepts the command and pulses completion.

## Current limitations

This is an initial scaffold, not a completed production-grade UVM environment. The scoreboard currently counts host requests/responses and tracks the expected JOB_CONFIG value, but full response correlation, command-level checking, robust reset handling, randomized backpressure, and functional coverage remain to be implemented. The first run should be treated as an integration/debug milestone, not as proof that the tests pass.

# GMC Register Map

All addresses are byte addresses. Registers are 32 bits wide and word-aligned. Unimplemented addresses return zero on reads and set the error indication on writes/reads. Reserved bits read as zero.

| Offset | Register | Access | Reset | Description |
|---|---|---|---|---|
| `0x00` | `GMC_CONTROL` | RW | `0x00000000` | bit 0 enable; bit 1 soft reset (write-one pulse); bit 2 interrupt enable |
| `0x04` | `GMC_STATUS` | RO | `0x00000001` | bit 0 ready; bit 1 engine busy; bit 2 error sticky; bit 3 command FIFO full |
| `0x08` | `COMMAND` | WO | — | bits [7:0] opcode; accepted valid opcodes enqueue a descriptor |
| `0x0C` | `JOB_CONFIG` | RW | `0x00000000` | bits [15:0] job ID for the next command |
| `0x10` | `IRQ_STATUS` | RO | `0x00000000` | bit 0 completion pending; bit 1 error pending |
| `0x14` | `IRQ_CLEAR` | WO | — | write-one-to-clear: bit 0 completion pending; bit 1 error pending; bit 2 error sticky |
| `0x18` | `ERROR_STATUS` | RO | `0x00000000` | bit 0 sticky error indicator |

## Access rules

- Reads of write-only registers return zero.
- Writes to read-only or unimplemented registers set the error indicator.
- Unaligned accesses are invalid and set the error indicator.
- Writing a supported opcode to COMMAND enqueues it if the FIFO is not full.
- Writing an unsupported opcode or writing COMMAND while the FIFO is full sets the error indicator and does not enqueue a descriptor.
- GMC_CONTROL bit 1 is a pulse request, not a stored bit. GMC_CONTROL bit 0 gates command acceptance; bit 2 enables IRQ assertion.
- IRQ pending bits are sticky. IRQ output is asserted when interrupt enable is set and either pending bit is set.
- External reset is synchronous and active-low.

## Implementation note

This document defines the intended behavior for the initial educational implementation. If the RTL and this specification diverge during development, update the specification and regression together rather than silently changing behavior.

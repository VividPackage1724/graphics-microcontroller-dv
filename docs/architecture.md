# GMC Architecture

## Block diagram

```text
 Host Register Interface
          |
          v
 +--------------------+       +----------------+
 | Register / Control |------>| Command FIFO   |----+
 | and Error Tracking |       | 8 x 24-bit     |    |
 +--------------------+       +----------------+    v
          |                                  +------------------+
          +---------- IRQ ------------------>| GPU Command       |
                                             | Ready/Valid Port  |
                                             +------------------+
                                                       |
                                                       v
                                                External GPU Engine
                                          busy / done / error feedback
```

## Data path

A command descriptor is 24 bits: opcode in bits [7:0] and job ID in bits [23:8]. A host write to COMMAND pushes a descriptor into the FIFO. The dispatcher presents the FIFO head on the GPU command interface and pops it only on a valid/ready handshake.

## Control path

The control register holds enable and interrupt-enable bits. A write-one soft-reset request clears the GMC's internal control/status/FIFO state while leaving the external reset input as the highest-priority reset. The status register reports ready, engine busy, sticky error, and FIFO-full state.

Completion and error events set sticky IRQ pending bits. IRQ output is the OR of pending bits gated by interrupt enable. Software clears pending bits by writing the corresponding ones to IRQ_CLEAR.

## Verification focus

- Reset values and soft reset
- Register access policy, alignment, and reserved bits
- FIFO ordering, empty/full boundaries, and backpressure
- Payload stability during downstream stalls
- Supported and unsupported opcodes
- Sticky error and interrupt behavior
- Completion/error events and recovery

# Port description

Detailed handshake protocol and timing for `crc_top`.

## Reset

`rst_ni` is **synchronous active-low**. Hold it low for at least 4
clock cycles before the first command. After de-assertion, the core
is in `S_IDLE` with `init_ready_o = 1`.

```
clk_i       __|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_
rst_ni      ‾‾‾‾‾‾‾|_______________________|‾‾‾‾‾‾‾‾‾‾
init_ready_o       X X X X X X X X X X X X X 1 1 1 1
```

## Session start

A new CRC computation is initiated by pulsing `init_i` for one cycle.
The core internally:

1. Loads `INIT[WIDTH-1:0]` into the running CRC register.
2. Clears the byte counter to zero.
3. Transitions from `S_IDLE` (or `S_DONE`) into `S_BYTE`, where
   `byte_ready_o` is high and the engine is ready for input.

```
clk_i        |‾|_|‾|_|‾|_|‾|_|‾|_
init_ready_o ‾‾‾|________________
init_i       ___|‾‾|_____________
byte_ready_o _____|‾‾‾‾‾‾‾‾‾‾‾‾‾
```

`init_ready_o` is high in `S_IDLE` (post-reset) and `S_DONE` (after
a prior session has produced its result). Driving `init_i` while
`init_ready_o = 0` is ignored.

## Byte streaming

Each input byte is consumed on a `byte_valid_i & byte_ready_o`
handshake. The core can accept one byte per cycle in steady state.

```
clk_i         |‾|_|‾|_|‾|_|‾|_|‾|_|‾|_
byte_ready_o  ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
byte_valid_i  ___|‾‾|___|‾‾|___|‾‾|___
byte_i        ___|b0|___|b1|___|b2|___
byte_last_i   _____________________|‾|
```

`byte_last_i` together with `byte_valid_i` on the final byte
signals end-of-message. The next cycle the engine transitions from
`S_BYTE` into `S_FINAL`, applies REFOUT (bit-reverse the running
CRC) and XOROUT (final XOR), and registers the result. One cycle
later the engine sits in `S_DONE` with `crc_valid_o = 1` and
`crc_o` holding the finalised CRC.

## Explicit finalize

If the producer cannot mark the last byte with `byte_last_i` (for
example because the message length is signalled out-of-band), it
may pulse `finalize_i` for one cycle in `S_BYTE` after the last
byte has been accepted. The result is identical:

```
clk_i        |‾|_|‾|_|‾|_|‾|_|‾|_|‾|_
byte_valid_i ___|‾‾|___|‾‾|___________
byte_last_i  _____________________
finalize_i   _________________|‾‾|___
crc_valid_o  ____________________|‾‾‾
crc_o        ____________________|crc
```

`finalize_i` also handles the **empty-message** case: pulse `init_i`
in cycle N, pulse `finalize_i` in cycle N+1 (when the engine is in
`S_BYTE`), and `crc_o` will be `INIT ^ XOROUT` (after REFOUT) — the
canonical CRC of an empty input.

## 32-bit-parallel ingress (when `WORD_PARALLEL=1`)

For high-throughput pipelines (Ethernet MAC, NVMe-TCP, packet
classifiers) instantiate the core with `WORD_PARALLEL=1`. A second
ingest interface (`word_*`) consumes a 32-bit word per cycle. Each
chunk carries `word_byte_count_i` (1..4) so the final partial word
can be presented in the same handshake.

```
clk_i             |‾|_|‾|_|‾|_|‾|_|‾|_
word_ready_o      ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
word_valid_i      ___|‾‾|___|‾‾|___|‾‾|
word_i            ___|w0|___|w1|___|w2|
word_byte_count_i ___|4 |___|4 |___|3 |
word_last_i       ___________________|‾|
```

Byte order inside `word_i` depends on `REFIN`:

- `REFIN = 1`: byte 0 is the **least-significant** byte of `word_i`
  (matches packet-byte-stream conventions, `crcmod`, `zlib.crc32`).
- `REFIN = 0`: byte 0 is the **most-significant** byte of `word_i`.

The byte-mode and word-mode interfaces share the same FSM and the
same finalisation path; results are identical for the same byte
sequence regardless of which interface delivered it (intended; not
verified). The testbench is intended to check this equivalence on all
edge-case lengths and on every tenth random vector; results not
independently confirmed.

## Output handshake

`crc_o` and `crc_valid_o` go high simultaneously when the engine
enters `S_DONE`. They stay high until the next `init_i` pulse, so
the consumer has unbounded time to read the result. There is no
back-pressure on the output — the result is held in a register and
does not require a `ready` from the consumer.

`byte_count_o` reports the number of bytes accepted in the current
session. It increments on every `byte_take` or `word_take`
handshake, holds across `S_FINAL` and `S_DONE`, and resets on the
next `init_i`.

## Endianness summary

- `byte_i[7:0]`: a single byte of the message in natural byte order.
- `word_i`: with `REFIN = 1` byte 0 is in `word_i[7:0]`, byte 1 in
  `[15:8]`, etc. With `REFIN = 0` byte 0 is in `word_i[31:24]`.
- `crc_o[WIDTH-1:0]`: the finalised CRC after REFOUT and XOROUT.
  Byte 0 of the on-the-wire encoding depends on the protocol — for
  Ethernet, `crc_o[7:0]` is the first FCS byte transmitted (lowest
  octet first).

## Latency summary

For a message of N bytes (intended cycle counts; not verified):

| Phase                  | Cycles                          |
|------------------------|---------------------------------|
| Init capture           | 1                               |
| Per data byte          | 1                               |
| Final + DONE register  | 2                               |
| Total                  | `3 + N` cycles (byte mode)      |
| Total                  | `3 + ceil(N / 4)` (word mode)   |

At 100 MHz, byte-mode throughput would be ~100 MB/s per core and
word-mode ~400 MB/s, or 3.2 Gb/s, which would be enough for line-rate
Gigabit Ethernet FCS at 200 MHz (unverified estimates).

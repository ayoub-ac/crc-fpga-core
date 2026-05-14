# Security model

This document describes what `crc_top` is designed to defend against
and what it is **not** designed to defend against. If you need an
authenticator for a security-sensitive protocol, this is the wrong
primitive — read the threat model below and pick a MAC instead.

## CRCs are for accidental errors, NOT for authentication

A CRC is a **non-cryptographic** error-detection code. It catches:

- random bit flips on a noisy link,
- truncated / dropped packets,
- frame misalignment,
- whole-byte corruption from buffer overruns,
- stale cache reads where the message has been rewritten.

A CRC does **not** catch:

- An attacker who knows the polynomial and chooses bytes to make the
  CRC come out right. CRC is linear over GF(2) — given any message
  and CRC, an attacker can flip arbitrary bits and adjust other
  bytes to keep the CRC valid.
- Replay attacks (the CRC of last hour's frame is still valid this
  hour).
- Bit flips in the CRC field itself that happen to land on a
  collision class.

In other words: if you need to detect **accidents**, use a CRC. If
you need to detect **adversaries**, use a cryptographic MAC
(HMAC-SHA-256, BLAKE2-MAC, KMAC, or AES-GMAC). They are not
interchangeable.

## What this core promises

1. **Correct per-RFC standard outputs.** Five named standards are
   directly verified against Python `crcmod`:
   - CRC-32 (Ethernet, ZIP, gzip),
   - CRC-32C (iSCSI, SCTP, Btrfs, ext4 metadata),
   - CRC-16-CCITT (X.25, PPP, HDLC),
   - CRC-16-IBM (Modbus RTU),
   - CRC-8 (CAN, NRSC-5, SAE J1850).
2. **Determinism.** Same input bytes, same polynomial / init / refin
   / refout / xorout parameters → same CRC, every time, on every
   target. No race conditions, no clock-domain crossings inside the
   core (the core is single-clock).
3. **Bit-exact match with software.** The core agrees byte-for-byte
   with `crcmod.predefined`, `zlib.crc32`, `binascii.crc_hqx`, the
   Linux kernel `crc32_le` / `crc32c_le`, and the Modbus reference
   implementation.
4. **No undefined values on any port.** All outputs are registered;
   `crc_o` is only valid when `crc_valid_o = 1`. `byte_count_o`
   monotonically increases over a session and resets on `init_i`.

## What this core does NOT promise

1. **Authentication.** This is a CRC, not a MAC. Do not use the
   output as evidence of message authenticity.
2. **Side-channel resistance.** No timing, power, or EM-emission
   countermeasures. The core processes one byte per cycle in byte
   mode regardless of the data, so simple timing-based side
   channels are limited; but the polynomial-division XOR network
   is data-dependent and an adversary with a power probe could
   distinguish bytes.
3. **Fault injection resistance.** No double-modular redundancy, no
   parity on the running CRC register, no spare-channel comparison.
   If your safety case requires SIL-3 or ASIL-D mitigation against
   single-event upsets, instantiate two of these cores and compare,
   or wrap the running CRC in a parity check.
4. **Cryptographic resistance to chosen-input collisions.** Trivial
   to break — that is what CRCs are. Do not use as a hash.

## Reporting issues

If you find:

- a deviation from `crcmod` for one of the five named standards,
- an FSM lock-up,
- a non-deterministic output on the same input,
- a synthesis-time elaboration failure on Yosys / Vivado / Quartus,

open an issue at <https://github.com/ayoub-ac/crc-fpga-core/issues>
with the input bytes, the parameter set, and the observed output. The
testbench includes 100 random vectors per standard; fresh
counter-examples are welcome.

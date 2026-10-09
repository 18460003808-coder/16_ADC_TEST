# ADS7953 project instructions

This repository is an ADS7953 acquisition system for an EP4CE30F23C8 FPGA. Read `CODEX_HANDOFF.md` and `NEW/每种工程完整通信流程.txt` before changing FPGA RTL, host software, protocols, constraints, or documentation.

## Scope and safety

- Do not inspect, modify, move, delete, or package `NPWM_DAC`; it is unrelated and explicitly out of scope.
- `NEW/` contains the recommended maintained projects. Preserve the older `ADS7953_0-5V/` and `ADS7953_20Board_SharedSPI/` trees as reference/baseline versions unless the user explicitly asks to change them.
- Do not delete pin-constraint files. A prior deletion caused the FPGA project to fail and had to be restored.
- The authoritative pin baseline for future ADS7953 work is the effective Quartus assignment set of `NEW/ADS7953_NBoard_UART`. The user changed these assignments through the Quartus GUI on 2026-10-06. Resolve them from the active project QSF, including its sourced `constraints/pins.qsf` and the later GUI-generated overrides in `ADS7953_NBoard_UART.qsf`; do not treat either file alone, a legacy project, or a `.bak` file as the complete baseline.
- Preserve unrelated user edits and `.bak` files. Do not replace current clock settings from backups without explicit direction.
- Before every ModelSim/Questa simulation run, obtain explicit user permission. Do not treat an earlier approval as permanent approval for a later RTL revision.
- Do not infer that successful compilation proves hardware behavior. State separately what was compiled, simulated, GUI-tested, and tested on physical hardware.

## Recommended project set

- `NEW/ADS7953_1Board_UART`: one-board teaching project, UART host, current SPI clock 1 MHz.
- `NEW/ADS7953_1Board_NET`: one-board teaching project, UDP host, SPI clock 10 MHz.
- `NEW/ADS7953_NBoard_UART`: macro-configurable 1–20 board project, UART host, current SPI clock 1 MHz.
- `NEW/ADS7953_NBoard_NET`: macro-configurable 1–20 board project, UDP host, SPI clock 10 MHz.
- N-board count is controlled by `rtl/ads7953_board_count.vh`; legal range is 1–20 and the maintained default is 1.

Earlier UART variants under `ADS7953_20Board_SharedSPI/` are not protocol-identical:

- `fpga_2board`: fixed two boards, returns two 40-byte data frames and no end frame.
- `fpga_20board`: defaults to 20 boards and accepts `43` followed by one binary count byte `01`–`14`; a `54` trigger returns that many 40-byte frames and no end frame.
- `fpga_Nboard` and `fpga_Nboard.zip`: macro-configured N-board UART protocol with the 8-byte end frame.
- `fpga_Nboard_NET`: macro-configured N-board UDP protocol with the 8-byte end frame.

Each maintained host project provides main, AllChannels, Scope, and FreeRun variants. FreeRun sends ASCII `T` periodically without waiting for the previous response; the FPGA ignores triggers received while busy.

## ADS7953 SPI behavior

- CS is active low, 16 SCLK pulses per word, MSB first, FPGA samples SDO on rising SCLK edges.
- Per-board commands are `16'h93C0` (Auto-2 last channel CH15), `16'h3C40` (enter Auto-2, restart CH0, select 0–2×VREF), followed by `16'h0000` continuously.
- Discard the first three returned words. Normally word 4 returns CH0 and word 19 returns CH15.
- SDO is `{channel[3:0], conversion_code[11:0]}`. Store only an ordered CH0 through CH15 sweep.
- The maintained readers have `MAX_FRAME_COUNT=32`. If a full ordered sweep is not obtained, they stop SCLK, release CS, clear that board's data, and assert completion so a missing board cannot deadlock the system.
- `NEW/ADS7953_NBoard_UART` carries a backward-compatible board-level SPI error flag in bit7 of the CH0 high byte (application byte 8); its Diagnostic host highlights a timed-out board. Other maintained projects have no per-board valid/online flag. The flag means the ordered sweep failed, not that the board is definitively offline.

## Host protocols

Trigger command for UART and UDP is one byte: ASCII `T`, hex `54`.

The common 40-byte data frame used by all multi-board projects is:

`A5 5A 01 Board 20 SeqLo SeqHi [CH0Lo CH0Hi ... CH15Lo CH15Hi] XOR`

End frame, 8 bytes:

`A5 5A 01 FF BoardCount SeqLo SeqHi XOR`

The end frame is used by `fpga_Nboard`, `fpga_Nboard_NET`, and the maintained `NEW` projects, but not by early `fpga_2board`/`fpga_20board`. XOR excludes `A5 5A` and includes all bytes from protocol version through the last field before the checksum. A maintained acquisition is `N*40+8` application bytes. UART is 115200 8-N-1. UDP defaults are FPGA `02:00:00:00:79:53`, `192.168.1.50:5000`, host `192.168.1.10:5001`, discovery/trigger broadcast `192.168.1.255:5000`.

Legacy `ADS7953_0-5V` uses a different 36-byte frame:

`A5 5A 20 [32 channel bytes] XOR`

It has no version, board number, sequence, board count, or end frame. Never parse it with the maintained 40/8-byte parser.

## Connector display mapping

Raw FPGA frames remain in ADC CH0–CH15 order. Maintained host displays map local IV0–IV15 to ADC channels:

`(14, 12, 10, 8, 13, 15, 9, 11, 5, 7, 1, 3, 6, 4, 2, 0)`

For board `b`, displayed global IV numbers are `b*16` through `b*16+15`.

## Change discipline

- Make surgical changes only in the requested project variants.
- When the user later asks to create, repair, or synchronize another ADS7953 project, use the effective `NEW/ADS7953_NBoard_UART` pin set. For NET projects, retain Ethernet/GMII-only assignments and synchronize only common clock/reset/SPI/CS signals. Do not overwrite other existing QSF files merely to pre-emptively synchronize them.
- When changing a shared protocol or reader, check all four maintained copies for intentional consistency.
- If changing frame fields, update RTL packetization, UART and UDP parsers, all GUI variants, exports, tests, and both communication text documents together.
- If changing board count, perform a full Quartus compile; do not assume editing the macro alone updates the existing SOF.
- Keep generated SOF and packaged EXE files only when they correspond to the checked-in source; record regeneration in `NEW/CHANGELOG.md` and verification in `NEW/验证报告.md`.

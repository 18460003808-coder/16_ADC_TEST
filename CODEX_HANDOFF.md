# ADS7953 Codex handoff

This file preserves the working context needed when the project is opened by Codex on another computer. The primary technical reference is [NEW/每种工程完整通信流程.txt](NEW/每种工程完整通信流程.txt); the compact frame reference is [NEW/所有工程通信帧结果.txt](NEW/所有工程通信帧结果.txt).

## User intent

The desired architecture is:

1. A one-board teaching project.
2. A recommended N-board project controlled by a compile-time macro for 1–20 boards.
3. Both UART and Ethernet/UDP transport variants.
4. Host programs that dynamically use the board count actually reported by the end frame.
5. Main, all-channels, oscilloscope-style, and fixed-period FreeRun host views.
6. A bounded SPI scan so unplugged/floating ADC boards cannot make SCLK run forever or deadlock the host workflow.

## Directory map

- `hardware/`: shared ADS7953 datasheet and context cache.
- `ADS7953_0-5V/`: preserved legacy one-board UART project. It uses the old 36-byte return protocol and has no 32-frame missing-board guard.
- `ADS7953_20Board_SharedSPI/fpga_2board/`: preserved fixed two-board UART project; two 40-byte frames, no end frame.
- `ADS7953_20Board_SharedSPI/fpga_20board/`: preserved runtime-count UART project; `43` plus a binary count byte sets 1–20 boards, `54` triggers, and the response has N 40-byte frames with no end frame.
- `ADS7953_20Board_SharedSPI/fpga_Nboard/` and `fpga_Nboard.zip`: preserved macro-configured UART project using N data frames plus an 8-byte end frame.
- `ADS7953_20Board_SharedSPI/fpga_Nboard_NET/`: preserved macro-configured UDP project using N data frames plus an 8-byte end frame.
- These earlier SharedSPI readers do not contain the new 32-frame guard.
- `NEW/`: recommended maintained project family and current documentation.
- `NEW/ADS7953_1Board_UART/`: fixed one board, UART, current top-level SCLK setting 1 MHz.
- `NEW/ADS7953_1Board_NET/`: fixed one board, UDP, SCLK 10 MHz.
- `NEW/ADS7953_NBoard_UART/`: macro 1–20 boards, UART, current top-level SCLK setting 1 MHz.
- `NEW/ADS7953_NBoard_NET/`: macro 1–20 boards, UDP, SCLK 10 MHz.
- `NEW/ADS7953_NBoard_UART_SLIDE/`: derivative of the current N-board UART project, plus 2 kHz slide pulses, the AllChannels linked-run host, standalone named Excel export, and background 320×N grayscale preview with optional PNG export. Its maintained host executables are the SLIDE AllChannels build and the Scope build.

Do not touch `NPWM_DAC`.

## FPGA target and physical design

- FPGA: Cyclone IV E `EP4CE30F23C8`.
- System clock: 50 MHz.
- ADC: ADS7953, 12-bit, 16 channels.
- Reference: 2.5 V; Range 2 produces a nominal 0–5 V input range.
- N-board bus: SCLK, SDI, and SDO are shared; each board has an independent active-low CS. The controller selects only one CS at a time and scans boards sequentially.
- Hardware manuals and the ADS7953 datasheet are included.

### Authoritative pin baseline designated on 2026-10-06

The user changed pins through the Quartus GUI and designated the resulting effective assignments of `NEW/ADS7953_NBoard_UART` as the baseline for all future ADS7953 work.

This baseline is composite, not a single file:

1. `ADS7953_NBoard_UART.qsf` sources `constraints/pins.qsf`.
2. Later GUI-generated assignments in the main QSF override CS1–CS19.
3. CS0, clock, reset, UART, shared SPI, I/O standards, and drive strengths currently come from the sourced file.

Designation-time hashes:

- main QSF: `EFF4CE49A5B436B7EDCF1A1442365AFF5CEF9C731343FB9B057F92BFFBD7769D`
- sourced pins QSF: `B0755C9B953BAFEF51BBDB9275FCCFD640E3C94B20CC44490D037F269AD42C1A`

The resolved baseline is documented in `NEW/引脚约束基准.md`. Do not reconstruct pins from old projects or `.bak` files. A one-board derivative uses the resolved CS0. A NET derivative keeps its Ethernet/GMII-specific pins and takes only common signals from this baseline. Existing other projects have not automatically been synchronized or recompiled.

## Exact ADC transaction

For each selected board the RTL transmits 16-bit, MSB-first words:

1. `93C0`: program Auto-2 last channel to CH15.
2. `3C40`: enter Auto-2, restart at CH0, select Range 2, normal power, return channel address on SDO.
3. `0000`: continue current mode; pipeline warm-up.
4. Continue sending `0000`. The fourth returned word should be `{0, CH0_code}` and subsequent words should be `{1, CH1_code}` through `{F, CH15_code}`. A normal scan therefore ends after 19 words or 304 SCLK periods.

The maintained reader checks ordered channel nibbles rather than trusting positional data. It can resynchronize on CH0. The first three responses are intentionally ignored because of configuration and conversion pipeline latency.

Current maintained missing-board behavior is capped at 32 words per selected board. On timeout, the whole board slice is zeroed, CS is released, SCLK stops, and completion is raised. The N-board controller then advances to the next board.

## Transport behavior

All hosts trigger using byte `0x54` (`T`). FPGA transports accept it only while the ADC controller and packet sender are idle; extra triggers are ignored, not queued.

Common multi-board data frame (40 bytes):

| Offset | Meaning |
|---:|---|
| 0–1 | `A5 5A` |
| 2 | protocol version `01` |
| 3 | zero-based board ID |
| 4 | payload length `20` hex = 32 bytes |
| 5–6 | 16-bit acquisition sequence, little-endian |
| 7–38 | CH0–CH15, two bytes per 12-bit code, little-endian |
| 39 | XOR of bytes 2–38 |

End frame (8 bytes): `A5 5A 01 FF N SeqLo SeqHi XOR`, with XOR over bytes 2–6. It is present in `fpga_Nboard`, `fpga_Nboard_NET`, and all maintained `NEW` variants. It is absent in early `fpga_2board` and `fpga_20board`. A maintained/end-frame round is `N*40+8` bytes: 48 bytes for one board, 88 for two, and 808 for twenty. Early fixed/runtime-count UART rounds are exactly `N*40` bytes.

The SLIDE derivative additionally accepts `55 AA 4D Dir PulseLo PulseHi XOR`, where XOR covers bytes 2–5 and `Dir=1` is forward. After the physical pulse train finishes, it returns `A5 5A 01 FE 01 Dir PulseLo PulseHi XOR`, with XOR over bytes 2–7. `pwm_out` is PIN_A20 and `dir` is PIN_A19. The host waits for this hardware completion frame before advancing its linked state machine.

The SLIDE AllChannels host keeps each linked run in memory until the rail has returned home, then prompts the user for a filename and creates a new standalone workbook. It does not append linked runs to an older workbook. Cancelling the dialog retains the pending run in memory and changes the button to `保存联动数据`.

The same host can load a generated vertical workbook (`A2:A321 = IV0..IV319`) and create an `N x 320` 8-bit grayscale PNG. Rows are IV0..IV319 and columns are captures. Excel values are millivolts; configurable black/white thresholds are entered in volts and default to 0 V/5 V. Values are clipped and mapped linearly; blank cells map to black.

UART is 115200 8-N-1. At that rate the wire time is about 4.167 ms for one board, 7.639 ms for two, and 70.139 ms for twenty, excluding ADC acquisition.

UDP uses FPGA MAC `02:00:00:00:79:53`, FPGA IP `192.168.1.50`, local UDP port 5000, host default `192.168.1.10:5001`, and broadcast trigger `192.168.1.255:5000`. The FPGA records the requester's source MAC/IP/UDP port and replies directly with one UDP datagram containing the complete application frame group. UDP checksum is zero; IPv4 header checksum and Ethernet FCS are generated in RTL.

## Host behavior

- Main view: dynamically shows boards received in the current complete round.
- AllChannels: one page; board 0 is global IV0–IV15, board 1 IV16–IV31, and so on.
- Scope: selectable multiple IV channels with real-time traces; NET scope supports horizontal and vertical scale settings.
- FreeRun: periodic trigger thread does not wait for FPGA feedback; receive/parsing remains independent. Default interval is 100 ms and duration 0 means unlimited.
- Raw frame payload is ADC channel order. Display/export uses `IV_TO_CHANNEL = (14,12,10,8,13,15,9,11,5,7,1,3,6,4,2,0)` per board.
- `NEW/ADS7953_NBoard_UART` has a backward-compatible board-level SPI error flag in bit7 of the CH0 high byte (application byte 8): 1 means the 32-word bound was reached without a complete ordered sweep. Its Diagnostic host highlights all 16 values red. Other maintained projects still have no valid bit. The flag reports acquisition failure, not a definitive online/offline state.

## Clock details that are easy to misread

- Current maintained UART tops are set to 1 MHz: `NEW/ADS7953_1Board_UART` and `NEW/ADS7953_NBoard_UART`.
- Current maintained NET tops are set to accurate 10 MHz using asymmetric 2/3 system-clock phases: `NEW/ADS7953_1Board_NET` and `NEW/ADS7953_NBoard_NET`.
- The legacy `ADS7953_0-5V` and earlier `fpga_Nboard_NET` request 10 MHz but their symmetric ceil divider produces about 8.333 MHz from 50 MHz.
- `.bak` files may contain different values. Preserve the active source value unless the user explicitly requests a clock change.

## Verification history and current caution

- The four maintained projects completed full Quartus 13.1 compilation with zero errors after the bounded-scan RTL change, and their `output_files` contain SOF files.
- Earlier ModelSim tests passed for one-board UART/NET readers and N-board UART/NET configurations including high board counts. After the later 32-frame no-board regression was added to the one-board testbenches, those revised simulations were not rerun because a new explicit permission was still required.
- Host parser/view tests and packaged EXE startup smoke tests had passed when generated.
- On 2026-10-08 the SLIDE derivative passed its current 13 Python tests. Earlier revisions also passed GUI/EXE startup checks and a 20-board Quartus 13.1 full compile with 0 errors. The current final AllChannels EXE is `host/dist/ADS7953_NBoard_AllChannels_UART_SLIDE.exe` (SHA-256 `4F0E1388555E043FA88E32B317E1E6C9C830710B1E456937891239E202550FFD`). No ModelSim or physical-slide validation was performed for this revision.
- Treat these as historical results, not a substitute for rerunning the relevant checks after edits.
- Obtain explicit permission before every future ModelSim run.

## Known history and constraints

- A pin-constraint file was once deleted at the user's request and the design stopped working; it was restored. Never remove constraints casually.
- SDO and SCLK pins were previously swapped in hardware constraints and later corrected. Hardware wiring is now considered correct by the user.
- On 2026-10-06 the user made additional assignments through the Quartus GUI and designated the effective `NEW/ADS7953_NBoard_UART` assignment set as the future baseline. If older documentation conflicts with it, the current effective Quartus assignments win.
- The user does not want a single trigger to produce endless SCLK because it can make the system appear hung. Preserve the maintained 32-frame stop behavior.
- Old project protocols are retained only for compatibility and must not silently replace the maintained protocol.

## Useful documents

- `NEW/README.md`: maintained project overview.
- `NEW/通信帧格式.md`: maintained application protocol.
- `NEW/每种工程完整通信流程.txt`: detailed per-project PC → FPGA → ADC → FPGA → PC flow.
- `NEW/所有工程通信帧结果.txt`: compact all-project frame reference and examples.
- `NEW/验证报告.md`: verification record.
- `NEW/CHANGELOG.md`: change history.
- `hardware/chip reference/ads7953.pdf`: authoritative ADC datasheet.

## Recommended first actions on another computer

1. Read `AGENTS.md`, this handoff, and the two communication text files.
2. Confirm which project variant the user intends to change.
3. Check active source and macro values; do not infer them from `.bak` files.
4. For FPGA changes, compile the exact selected project and retain the new SOF only if compilation succeeds.
5. Ask permission immediately before running ModelSim.
6. For host changes, run the relevant parser/view tests and smoke-test the generated EXE.

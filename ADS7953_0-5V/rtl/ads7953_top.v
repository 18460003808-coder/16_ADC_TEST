`timescale 1ns/1ps

module ads7953_top #(
    parameter integer CLK_HZ    = 50_000_000,
    parameter integer UART_BAUD = 115_200
) (
    input  wire clk,
    input  wire rst_n,
    input  wire uart_rxd,
    output wire uart_txd,
    output wire adc_cs_n,
    output wire adc_sclk,
    output wire adc_sdi,
    input  wire adc_sdo,

    output wire         ready,
    output wire         busy,
    output wire         sample_valid,
    output wire [3:0]   sample_channel,
    output wire [11:0]  sample_code,
    output wire [15:0]  sample_mv,
    output wire         scan_done,
    output wire [2:0]   debug_state,
    output wire [15:0]  debug_tx_word,
    output wire [15:0]  debug_rx_shift,
    output wire [3:0]   debug_expected_channel,
    output wire         trig_internal,
    output wire         uart_packet_busy
);

    // Kept as internal nodes for SignalTap or connection to subsequent logic.
    (* keep = "true" *) wire [191:0] adc_codes;

    ads7953_uart_bridge #(
        .CLK_HZ(CLK_HZ),
        .BAUD(UART_BAUD)
    ) u_uart_bridge (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rxd(uart_rxd),
        .uart_txd(uart_txd),
        .adc_ready(ready),
        .scan_done(scan_done),
        .adc_codes(adc_codes),
        .trig_pulse(trig_internal),
        .packet_busy(uart_packet_busy)
    );

    ads7953_16ch_reader #(
        .CLK_HZ(CLK_HZ),
        .SCLK_HZ(10_000_000)
    ) u_ads7953_reader (
        .clk(clk),
        .rst_n(rst_n),
        .trig(trig_internal),
        .adc_cs_n(adc_cs_n),
        .adc_sclk(adc_sclk),
        .adc_sdi(adc_sdi),
        .adc_sdo(adc_sdo),
        .ready(ready),
        .busy(busy),
        .sample_valid(sample_valid),
        .sample_channel(sample_channel),
        .sample_code(sample_code),
        .sample_mv(sample_mv),
        .scan_done(scan_done),
        .adc_codes(adc_codes),
        .debug_state(debug_state),
        .debug_tx_word(debug_tx_word),
        .debug_rx_shift(debug_rx_shift),
        .debug_expected_channel(debug_expected_channel)
    );

endmodule
